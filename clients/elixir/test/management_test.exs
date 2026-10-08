defmodule DASP.ManagementTest do
  use ExUnit.Case, async: true
  alias DASP.{Client, Duplex, OutputQueue}

  @host "urn:host:one"
  @source "urn:client:one"
  @session %{
    "session_id" => "a",
    "actor_id" => "actor",
    "profile" => %{"id" => "urn:profile:one", "version" => "1"}
  }

  defp event(kind, data, request_id \\ "request") do
    %{
      "specversion" => "1.0",
      "id" => "event-" <> Integer.to_string(System.unique_integer([:positive])),
      "source" => @host,
      "type" => "dasp.v1." <> kind,
      "datacontenttype" => "application/json",
      "requestid" => request_id,
      "data" => data
    }
  end

  defp update(id, sequence \\ 1),
    do:
      event("update", %{
        "session_id" => id,
        "sequence" => sequence,
        "kind" => "application",
        "command_id" => nil,
        "payload" => %{"name" => "changed", "data" => %{"value" => sequence}}
      })

  defp receipt(id, request_id \\ "request"),
    do:
      event(
        "receipt",
        %{
          "session_id" => id,
          "command_id" => "stable",
          "disposition" => "accepted",
          "admission_sequence" => 1,
          "error" => nil
        },
        request_id
      )

  defp progress(id, value),
    do:
      event("progress", %{
        "session_id" => id,
        "command_id" => "stable",
        "name" => "work",
        "payload" => %{"value" => value}
      })

  defp channel(tag \\ :one, opts \\ []) do
    owner = self()

    options =
      Keyword.merge(
        [
          host_source: @host,
          send: fn wire ->
            send(owner, {tag, :wire, JSON.decode!(wire)})
            :ok
          end,
          close: fn ->
            send(owner, {tag, :closed})
            :ok
          end,
          on_event: fn notice, state ->
            send(owner, {tag, :notice, notice})
            {:ok, state}
          end
        ],
        opts
      )

    pid = start_supervised!(Supervisor.child_spec({Duplex, options}, id: make_ref()))
    channel = Duplex.channel(pid)

    {:ok, client} =
      Client.new(
        source: @source,
        host_source: @host,
        transport: Duplex.transport(channel),
        validate_profile: fn _ -> true end,
        timeout: 1000
      )

    {channel, client}
  end

  defp request(tag \\ :one) do
    assert_receive {^tag, :wire, value}, 1000
    value
  end

  defp drain_started(c, attempts \\ 100) do
    cond do
      :ets.lookup_element(c.budget, :draining, 2) ->
        :ok

      attempts == 0 ->
        flunk("Drain did not start.")

      true ->
        Process.sleep(1)
        drain_started(c, attempts - 1)
    end
  end

  defp queued(q, value) do
    assert {:ok, {:queued, next}} = OutputQueue.enqueue(q, value)
    next
  end

  defp take(q) do
    assert {:ok, {%{event: event, token: token}, next}} = OutputQueue.take(q)
    assert {:ok, next} = OutputQueue.complete(next, token)
    {event, next}
  end

  test "legacy clients and output queues use the same identity checks as signals" do
    Process.flag(:trap_exit, true)

    for uri <- ["urn:host:one\n", "urn:host:%zz", "relative/path"] do
      assert {:error, %{code: :configuration}} =
               Client.new(
                 source: @source,
                 host_source: uri,
                 transport: fn _, _ -> {:error, :unused} end,
                 validate_profile: fn _ -> true end
               )

      assert {:error, %{code: :configuration}} =
               Duplex.start_link(host_source: uri, send: fn _ -> :ok end, close: fn -> :ok end)
    end

    {:ok, queue} = OutputQueue.new()

    failure =
      event("failure", %{
        "error" => %{"code" => "denied", "message" => "Denied", "retryable" => false}
      })

    assert {:ok, {:queued, _}} = OutputQueue.enqueue(queue, failure, "a")

    for id <- ["a\n", "", String.duplicate("a", 129)] do
      assert {:error, %{code: :configuration}} = OutputQueue.enqueue(queue, failure, id)

      assert {:error, %{code: :configuration}} =
               Duplex.start_link(
                 host_source: @host,
                 session_id: id,
                 send: fn _ -> :ok end,
                 close: fn -> :ok end
               )
    end
  end

  test "drain stops new requests and waits for the pending receipt" do
    {c, client} = channel()

    pending =
      Task.async(fn ->
        Client.submit(client, @session, %{
          "command_id" => "stable",
          "name" => "work",
          "input" => %{}
        })
      end)

    q = request()
    draining = Task.async(fn -> Duplex.drain(c, 500) end)
    drain_started(c)
    joined = Task.async(fn -> Duplex.drain(c, 1000) end)
    assert {:error, %{code: :draining}} = Client.read_view(client, @session)
    refute_receive {:one, :closed}
    assert :ok = Duplex.received(c, JSON.encode!(receipt("a", q["requestid"])))
    assert {:ok, %{data: %{"disposition" => "accepted"}}} = Task.await(pending)
    assert :ok = Task.await(draining)
    assert :ok = Task.await(joined)
    assert_receive {:one, :closed}
    assert_receive {:one, :notice, {:closed, %{code: :drained}}}
  end

  test "lost receipt at the first drain deadline preserves intent on a fresh connection" do
    {c, client} = channel()
    intent = %{"command_id" => "stable", "name" => "work", "input" => %{"amount" => 7}}
    pending = Task.async(fn -> Client.submit(client, @session, intent) end)
    first = request()
    draining = Task.async(fn -> Duplex.drain(c, 30) end)
    drain_started(c)
    joined = Task.async(fn -> Duplex.drain(c, 1000) end)
    assert :ok = Task.await(draining, 500)
    assert :ok = Task.await(joined, 500)
    assert {:error, %{code: :drain_timeout}} = Task.await(pending)
    {next, retry_client} = channel(:two)
    retry = Task.async(fn -> Client.submit(retry_client, @session, intent) end)
    second = request(:two)
    assert second["data"] == first["data"]
    refute second["requestid"] == first["requestid"]
    duplicate = put_in(receipt("a", second["requestid"]), ["data", "disposition"], "duplicate")
    assert :ok = Duplex.received(next, JSON.encode!(duplicate))
    assert {:ok, %{data: %{"disposition" => "duplicate"}}} = Task.await(retry)
    Duplex.close(next)
  end

  test "drain retains the last callback before the closed notice" do
    owner = self()

    observer = fn notice, state ->
      case notice do
        {:received, _, _} ->
          send(owner, {:callback, self()})

          receive do
            :release -> :ok
          end

        {:closed, _} ->
          send(owner, :closed_notice)

        _ ->
          :ok
      end

      {:ok, state}
    end

    {c, client} = channel(:one, on_event: observer)
    pending = Task.async(fn -> Client.read_view(client, @session) end)
    q = request()

    receiving =
      Task.async(fn ->
        Duplex.received(
          c,
          JSON.encode!(
            event("view", Map.merge(@session, %{"cursor" => 0, "state" => %{}}), q["requestid"])
          )
        )
      end)

    assert_receive {:callback, pid}
    draining = Task.async(fn -> Duplex.drain(c, 500) end)
    drain_started(c)
    refute_receive :closed_notice
    send(pid, :release)
    assert :ok = Task.await(receiving)
    assert {:ok, _} = Task.await(pending)
    assert :ok = Task.await(draining)
    assert_receive :closed_notice
  end

  test "a blocked scoped connection leaves another session usable" do
    owner = self()

    observer = fn notice, state ->
      if match?({:sent, _, _}, notice) do
        send(owner, {:callback, self()})

        receive do
          :release -> :ok
        end
      end

      {:ok, state}
    end

    {one, client_one} = channel(:one, session_id: "a", on_event: observer)
    {two, client_two} = channel(:two, session_id: "b")
    opening = Task.async(fn -> Client.open(client_one, @session) end)
    assert_receive {:callback, pid}

    try do
      session_two = Map.put(@session, "session_id", "b")
      pending = Task.async(fn -> Client.read_view(client_two, session_two) end)
      q = request(:two)

      reply =
        event(
          "view",
          Map.merge(session_two, %{"cursor" => 0, "state" => %{"alive" => true}}),
          q["requestid"]
        )

      assert :ok = Duplex.received(two, JSON.encode!(reply))
      assert {:ok, %{data: %{"state" => %{"alive" => true}}}} = Task.await(pending)
      Duplex.close(one)
      send(pid, :release)
      assert {:error, _} = Task.await(opening)
      refute_receive {:two, :closed}
    after
      send(pid, :release)
      Duplex.close(one)
      Duplex.close(two)
    end
  end

  test "driver readiness and session scope guard core traffic" do
    table = :ets.new(:ready, [:public])
    :ets.insert(table, {:ready, false})

    {c, client} =
      channel(:one, session_id: "a", is_ready: fn -> :ets.lookup_element(table, :ready, 2) end)

    assert {:error, %{code: :not_ready}} = Client.read_view(client, @session)
    refute_receive {:one, :wire, _}
    :ets.insert(table, {:ready, true})
    pending = Task.async(fn -> Client.read_view(client, @session) end)
    q = request()

    assert :ok =
             Duplex.received(
               c,
               JSON.encode!(
                 event(
                   "view",
                   Map.merge(@session, %{"cursor" => 0, "state" => %{}}),
                   q["requestid"]
                 )
               )
             )

    assert {:ok, _} = Task.await(pending)
    assert {:error, %{code: :correlation}} = Duplex.received(c, JSON.encode!(progress("b", 1)))
    assert_receive {:one, :closed}
    {unready, _} = channel(:two, is_ready: fn -> false end)

    assert {:error, %{code: :not_ready}} =
             Duplex.received(unready, JSON.encode!(progress("a", 1)))

    assert_receive {:two, :closed}
  end

  test "invalid drain deadlines leave admission open" do
    {c, _} = channel()

    for deadline <- [0, -1, 1.5, 2_147_483_648],
        do: assert({:error, %{code: :configuration}} = Duplex.drain(c, deadline))

    refute :ets.lookup_element(c.budget, :draining, 2)
    assert :ok = Duplex.drain(c, 10)
  end

  test "readiness loss during a send callback prevents handoff and closes the channel" do
    table = :ets.new(:ready, [:public])
    :ets.insert(table, {:ready, true})

    observer = fn notice, state ->
      if match?({:sent, _, _}, notice), do: :ets.insert(table, {:ready, false})
      {:ok, state}
    end

    {_c, client} =
      channel(:one, is_ready: fn -> :ets.lookup_element(table, :ready, 2) end, on_event: observer)

    assert {:error, %{code: :transport}} = Client.read_view(client, @session)
    refute_receive {:one, :wire, _}
    assert_receive {:one, :closed}
  end

  test "readiness loss after a completed exchange closes instead of retaining setup" do
    table = :ets.new(:ready, [:public])
    :ets.insert(table, {:ready, true})
    {c, client} = channel(:one, is_ready: fn -> :ets.lookup_element(table, :ready, 2) end)
    pending = Task.async(fn -> Client.read_view(client, @session) end)
    q = request()

    assert :ok =
             Duplex.received(
               c,
               JSON.encode!(
                 event(
                   "view",
                   Map.merge(@session, %{"cursor" => 0, "state" => %{}}),
                   q["requestid"]
                 )
               )
             )

    assert {:ok, _} = Task.await(pending)
    :ets.insert(table, {:ready, false})
    assert {:error, %{code: :transport}} = Client.read_view(client, @session)
    refute_receive {:one, :wire, _}
    assert_receive {:one, :closed}
    {_failed, failed_client} = channel(:two, is_ready: fn -> raise "Driver failed." end)
    assert {:error, %{code: :transport}} = Client.read_view(failed_client, @session)
    refute_receive {:two, :wire, _}
    assert_receive {:two, :closed}
  end

  test "fair output retains session order and charges the active lease" do
    {:ok, q} = OutputQueue.new()
    q = q |> queued(update("a", 1)) |> queued(update("a", 2)) |> queued(update("b"))
    assert {:ok, {%{session_id: "a", token: token}, next}} = OutputQueue.take(q)
    assert OutputQueue.usage(next).messages == 3
    assert {:ok, {nil, ^next}} = OutputQueue.take(next)
    assert {:error, %{code: :configuration}} = OutputQueue.complete(next, token + 1)
    {:ok, next} = OutputQueue.complete(next, token)
    {b, next} = take(next)
    assert b.data["session_id"] == "b"
    {a, next} = take(next)
    assert a.data["sequence"] == 2
    assert OutputQueue.usage(next).messages == 0
  end

  test "ordinary data and progress cannot consume control message reserves" do
    {:ok, q} = OutputQueue.new(max_messages: 3, reserved_control_messages: 1)
    q = q |> queued(update("a", 1)) |> queued(update("a", 2))
    assert {:error, %{code: :overflow}} = OutputQueue.enqueue(q, update("b"))
    assert {:ok, {:dropped, ^q}} = OutputQueue.enqueue(q, progress("b", 1))
    q = queued(q, receipt("b"))
    {r, q} = take(q)
    assert r.type == "dasp.v1.receipt"
    {a, q} = take(q)
    assert a.data["sequence"] == 1
    {a, _} = take(q)
    assert a.data["sequence"] == 2
  end

  test "control preference preserves session order and has a finite burst" do
    {:ok, q} = OutputQueue.new(max_control_burst: 2)
    q = q |> queued(update("a")) |> queued(receipt("a"))
    q = Enum.reduce(1..3, q, fn _, q -> queued(q, receipt("b")) end)
    {b, q} = take(q)
    assert b.data["session_id"] == "b"
    {b, q} = take(q)
    assert b.data["session_id"] == "b"
    {a, q} = take(q)
    assert a.type == "dasp.v1.update"
    {a, _} = take(q)
    assert a.type == "dasp.v1.receipt"
  end

  test "byte reserves remain available for a control reply" do
    a = update("a")
    b = receipt("b")
    {:ok, a_wire} = DASP.Wire.encode(a)
    {:ok, b_wire} = DASP.Wire.encode(b)

    {:ok, q} =
      OutputQueue.new(
        max_bytes: byte_size(a_wire) + byte_size(b_wire),
        reserved_control_bytes: byte_size(b_wire)
      )

    q = queued(q, a)
    assert {:error, %{code: :overflow}} = OutputQueue.enqueue(q, update("a", 2))
    q = queued(q, b)
    assert OutputQueue.usage(q).bytes == byte_size(a_wire) + byte_size(b_wire)
    {r, _} = take(q)
    assert r.type == "dasp.v1.receipt"
  end

  test "coalescing affects only adjacent matching progress" do
    {:ok, q} = OutputQueue.new()
    q = q |> queued(progress("a", 1)) |> queued(progress("a", 2))
    assert OutputQueue.usage(q).messages == 1
    q = q |> queued(update("a")) |> queued(progress("a", 3))
    {first, q} = take(q)
    assert first.data["payload"]["value"] == 2
    {second, q} = take(q)
    assert second.data["sequence"] == 1
    {third, _} = take(q)
    assert third.data["payload"]["value"] == 3
  end

  test "a busy session reaches its own count and byte limits before blocking another session" do
    {:ok, q} = OutputQueue.new(max_session_messages: 2)
    q = q |> queued(update("a", 1)) |> queued(update("a", 2))
    assert {:error, %{code: :overflow}} = OutputQueue.enqueue(q, update("a", 3))
    q = queued(q, update("b"))
    {:ok, {%{token: token}, q}} = OutputQueue.take(q)
    assert {:error, %{code: :overflow}} = OutputQueue.enqueue(q, update("a", 3))
    {:ok, q} = OutputQueue.complete(q, token)
    {b, _} = take(q)
    assert b.data["session_id"] == "b"
    a = Map.put(update("a"), "id", "byte-a")
    {:ok, wire} = DASP.Wire.encode(a)
    {:ok, q} = OutputQueue.new(max_session_bytes: byte_size(wire))
    q = queued(q, a)
    assert {:error, %{code: :overflow}} = OutputQueue.enqueue(q, update("a", 2))
    queued(q, a |> Map.put("id", "byte-b") |> put_in(["data", "session_id"], "b"))
  end

  test "resync discards unsent attachment data but keeps replies and source records" do
    {:ok, q} = OutputQueue.new()
    saved = update("a")
    before = JSON.encode!(saved)

    q =
      q
      |> queued(saved)
      |> queued(progress("a", 1))
      |> queued(receipt("a"))
      |> queued(update("b"))

    assert {:ok, {2, q}} = OutputQueue.discard_updates(q, "a")
    assert JSON.encode!(saved) == before
    {r, q} = take(q)
    assert r.type == "dasp.v1.receipt"
    {b, _} = take(q)
    assert b.data["session_id"] == "b"
  end

  test "invalid queue settings and closed lease reuse fail" do
    for options <- [
          [max_messages: 0],
          [max_bytes: 5, reserved_control_bytes: 5],
          [max_control_burst: 1.5]
        ],
        do: assert({:error, %{code: :configuration}} = OutputQueue.new(options))

    {:ok, q} = OutputQueue.new()
    {:ok, {_, q}} = q |> queued(update("a")) |> OutputQueue.take()
    q = OutputQueue.close(q)
    assert OutputQueue.usage(q).messages == 0
    assert {:error, %{code: :closed}} = OutputQueue.take(q)
  end
end
