defmodule DASP.LiveTest do
  use ExUnit.Case, async: true
  alias DASP.{Checkpoint, Live, Duplex, Client}

  @fixture File.read!(
             Path.expand("../../../conformance/fixtures/websocket-delivery-traces.json", __DIR__)
           )
           |> JSON.decode!()
  @session @fixture["session"]
  @host "urn:example:host:one"
  @source "urn:example:client:one"
  defp profile(_), do: true

  defp reduce(_state, %{data: %{"kind" => "application", "payload" => %{"data" => data}}}),
    do: data

  defp reduce(state, _), do: state

  defp event(kind, data, id \\ "request") do
    %{
      "specversion" => "1.0",
      "id" => "event-" <> Integer.to_string(System.unique_integer([:positive])),
      "source" =>
        if(String.ends_with?(kind, ".read") or kind == "session.open", do: @source, else: @host),
      "type" => "dasp.v1." <> kind,
      "datacontenttype" => "application/json",
      "requestid" => id,
      "data" => data
    }
  end

  defp initial(cursor) do
    {:ok, cp} =
      Checkpoint.from_view(
        event("view", Map.merge(@session, %{"cursor" => 0, "state" => %{"value" => 0}})),
        &profile/1
      )

    {:ok, cp} =
      Checkpoint.apply_updates(cp, Enum.take(@fixture["saved"], cursor), &reduce/2, &profile/1)

    cp
  end

  defp start(cursor \\ 0, opts \\ []) do
    {:ok, live} =
      Live.new(
        Keyword.merge(
          [
            checkpoint: initial(cursor),
            client_source: @source,
            reduce: &reduce/2,
            validate_profile: &profile/1
          ],
          opts
        )
      )

    live
  end

  defp open(live, head, id \\ "open") do
    {:ok, live} = Live.sent(live, JSON.encode!(event("session.open", @session, id)))

    {:ok, live} =
      Live.received(
        live,
        JSON.encode!(event("session.opened", Map.put(@session, "cursor", head), id))
      )

    live
  end

  for scenario <- @fixture["scenarios"] do
    test "execute live scenario #{scenario["id"]}" do
      scenario = unquote(Macro.escape(scenario))
      first = start(scenario["initial"]["cursor"])
      assert first.checkpoint["state"] == scenario["initial"]["state"]

      {live, discarded} =
        Enum.reduce(scenario["steps"], {first, 0}, fn step, {live, discarded} ->
          next =
            case step["action"] do
              "send" ->
                {:ok, next} =
                  Live.sent(live, JSON.encode!(step["event"]),
                    replay: step["event"]["type"] == "dasp.v1.updates.read"
                  )

                next

              "receive" ->
                {:ok, next} = Live.received(live, JSON.encode!(step["event"]))
                next

              "close" ->
                Live.close(live)

              "open-timeout" ->
                {:ok, next} = Live.timeout(live, Live.pending_open(live))
                next

              _ ->
                live
            end

          {next,
           discarded + if(step["action"] == "receive" and next.action == :discard, do: 1, else: 0)}
        end)

      expected = scenario["expected"]
      assert live.checkpoint["cursor"] == expected["cursor"]
      assert live.checkpoint["state"] == expected["state"]
      assert Atom.to_string(live.phase) == expected["phase"]
      assert live.target == expected["target"]
      assert discarded == expected["discardedReplies"]
    end
  end

  test "new attachment rejects rollback and allows only one pending open" do
    {:ok, live} = Live.sent(start(3), JSON.encode!(event("session.open", @session, "one")))

    assert {:error, %{code: :continuity}} =
             Live.received(
               live,
               JSON.encode!(event("session.opened", Map.put(@session, "cursor", 2), "one"))
             )

    assert {:error, %{code: :live}} =
             Live.sent(live, JSON.encode!(event("session.open", @session, "two")))

    assert {:error, %{code: :correlation}} =
             Live.sent(live, JSON.encode!(event("session.open", @session, "one")))

    assert {:ok, %{phase: :closed}} = Live.timeout(live, "one")
  end

  test "bounded buffers, gaps, and reducer failure preserve the previous checkpoint" do
    live = open(start(3, max_buffered_events: 1), 4)
    {:ok, first} = Live.received(live, JSON.encode!(Enum.at(@fixture["saved"], 4)))

    assert {:error, %{code: :overflow}} =
             Live.received(first, JSON.encode!(Enum.at(@fixture["saved"], 5)))

    bytes = open(start(3, max_buffered_bytes: 1), 4)

    assert {:error, %{code: :overflow}} =
             Live.received(bytes, JSON.encode!(Enum.at(@fixture["saved"], 4)))

    assert {:error, %{code: :gap}} =
             Live.received(live, JSON.encode!(Enum.at(@fixture["saved"], 5)))

    assert first.checkpoint["cursor"] == 3
    assert live.checkpoint["cursor"] == 3
  end

  test "ordinary explicit reads do not move the applied cursor" do
    live = open(start(), 0)

    q =
      event(
        "updates.read",
        %{"session_id" => @session["session_id"], "after" => 0, "limit" => 1},
        "read"
      )

    {:ok, live} = Live.sent(live, JSON.encode!(q))

    reply =
      event(
        "updates",
        %{
          "session_id" => @session["session_id"],
          "after" => 0,
          "next" => 1,
          "head" => 1,
          "events" => Enum.take(@fixture["saved"], 1)
        },
        "read"
      )

    {:ok, live} = Live.received(live, JSON.encode!(reply))
    assert live.checkpoint["cursor"] == 0
    assert Live.next_read(live) == nil
  end

  defp channel(opts \\ []) do
    owner = self()

    pid =
      start_supervised!(
        {Duplex,
         Keyword.merge(
           [
             host_source: @host,
             send: fn wire ->
               send(owner, {:wire, wire})
               :ok
             end,
             close: fn ->
               send(owner, :channel_closed)
               :ok
             end
           ],
           opts
         )}
      )

    Duplex.channel(pid)
  end

  defp client(channel, timeout \\ 1000) do
    {:ok, client} =
      Client.new(
        source: @source,
        host_source: @host,
        transport: Duplex.transport(channel),
        validate_profile: &profile/1,
        timeout: timeout
      )

    client
  end

  defp request do
    assert_receive {:wire, wire}, 1000
    JSON.decode!(wire)
  end

  defp observer(notice, live) do
    result =
      case notice do
        {:sent, event, wire} ->
          Live.sent(live, wire,
            replay: event.type == "dasp.v1.updates.read" and live.phase == :replay
          )

        {:received, _, wire} ->
          Live.received(live, wire)

        {:timeout, id} ->
          Live.timeout(live, id)

        {:closed, _} ->
          {:ok, Live.close(live)}
      end

    case result do
      {:ok, next} -> {:ok, next, cancel: MapSet.to_list(next.cancelled)}
      other -> other
    end
  end

  test "duplex dispatches concurrent replies and pushes with optional request IDs" do
    owner = self()

    channel =
      channel(
        on_event: fn notice, state ->
          send(owner, {:notice, notice})
          {:ok, state}
        end
      )

    c = client(channel)
    one = Task.async(fn -> Client.read_view(c, @session) end)
    two = Task.async(fn -> Client.read_outcome(c, @session, "cmd") end)
    requests = [request(), request()]
    view = Enum.find(requests, &(&1["type"] == "dasp.v1.view.read"))
    outcome = Enum.find(requests, &(&1["type"] == "dasp.v1.outcome.read"))

    assert :ok =
             Duplex.received(
               channel,
               JSON.encode!(
                 event(
                   "outcome",
                   %{
                     "session_id" => @session["session_id"],
                     "command_id" => "cmd",
                     "state" => "pending",
                     "sequence" => nil,
                     "outcome" => nil
                   },
                   outcome["requestid"]
                 )
               )
             )

    push = List.first(@fixture["saved"]) |> Map.put("requestid", view["requestid"])
    assert :ok = Duplex.received(channel, JSON.encode!(push))

    assert :ok =
             Duplex.received(
               channel,
               JSON.encode!(
                 event(
                   "view",
                   Map.merge(@session, %{"cursor" => 0, "state" => %{"value" => 0}}),
                   view["requestid"]
                 )
               )
             )

    assert {:ok, %{type: "dasp.v1.view"}} = Task.await(one)
    assert {:ok, %{data: %{"state" => "pending"}}} = Task.await(two)
    assert_receive {:notice, {:received, %{type: "dasp.v1.update"}, _}}
  end

  test "duplex drives fixed replay and saves before returning its reply" do
    owner = self()

    on_event = fn notice, live ->
      case observer(notice, live) do
        {:ok, next, opts} ->
          if next.action == :save, do: send(owner, {:saved, next.checkpoint})
          {:ok, next, opts}

        other ->
          other
      end
    end

    channel = channel(handler_state: start(3), on_event: on_event)
    c = client(channel)
    opening = Task.async(fn -> Client.open(c, @session) end)
    q1 = request()

    assert :ok =
             Duplex.received(
               channel,
               JSON.encode!(
                 event("session.opened", Map.put(@session, "cursor", 6), q1["requestid"])
               )
             )

    assert :ok = Duplex.received(channel, JSON.encode!(Enum.at(@fixture["saved"], 6)))
    assert {:ok, _} = Task.await(opening)
    live = Duplex.state(channel)
    assert Live.next_read(live)["limit"] == 3
    reading = Task.async(fn -> Client.read_updates(c, @session, 3, 3) end)
    q2 = request()

    reply =
      event(
        "updates",
        %{
          "session_id" => @session["session_id"],
          "after" => 3,
          "next" => 6,
          "head" => 7,
          "events" => Enum.slice(@fixture["saved"], 3, 3)
        },
        q2["requestid"]
      )

    assert :ok = Duplex.received(channel, JSON.encode!(reply))
    assert {:ok, _} = Task.await(reading)
    assert_receive {:saved, %{"cursor" => 7}}
    assert %{phase: :live, checkpoint: %{"cursor" => 7}} = Duplex.state(channel)
  end

  test "resync cancels replay in wire order and discards its late failure" do
    channel = channel(handler_state: start(3), on_event: &observer/2)
    c = client(channel)
    opening = Task.async(fn -> Client.open(c, @session) end)
    q1 = request()

    assert :ok =
             Duplex.received(
               channel,
               JSON.encode!(
                 event("session.opened", Map.put(@session, "cursor", 6), q1["requestid"])
               )
             )

    assert {:ok, _} = Task.await(opening)
    reading = Task.async(fn -> Client.read_updates(c, @session, 3, 3) end)
    q2 = request()

    resync =
      event(
        "resync.required",
        %{"session_id" => @session["session_id"], "head" => 6, "reason" => "overflow"},
        q2["requestid"]
      )

    assert :ok = Duplex.received(channel, JSON.encode!(resync))
    assert {:error, %{code: :resync}} = Task.await(reading)

    failure =
      event(
        "failure",
        %{
          "error" => %{"code" => "unavailable", "message" => "Unavailable.", "retryable" => true}
        },
        q2["requestid"]
      )

    assert :ok = Duplex.received(channel, JSON.encode!(failure))
    assert %{phase: :inactive, checkpoint: %{"cursor" => 3}} = Duplex.state(channel)
    refute_receive :channel_closed
  end

  test "open timeout closes the connection and rejects further work" do
    channel = channel()
    c = client(channel, 10)
    assert {:error, %{code: :timeout}} = Client.open(c, @session)
    assert_receive :channel_closed, 1000
    assert {:error, %{code: :closed}} = Client.read_view(c, @session)
  end

  test "malformed input and local byte bounds close pending work" do
    channel = channel()
    task = Task.async(fn -> Client.read_view(client(channel), @session) end)
    _q = request()
    assert {:error, _} = Duplex.received(channel, ~s({"type":1,"type":2}))
    assert {:error, _} = Task.await(task)
    assert_receive :channel_closed
  end

  test "local byte limit closes the channel before send" do
    channel = channel(max_queued_bytes: 1)
    assert {:error, %{code: :overflow}} = Client.read_view(client(channel), @session)
    assert_receive :channel_closed
    refute_receive {:wire, _}
  end

  test "queue count is bounded while an event callback is blocked" do
    owner = self()

    channel =
      channel(
        max_queued_messages: 1,
        on_event: fn notice, state ->
          if match?({:sent, _, _}, notice) do
            send(owner, {:blocked, self()})

            receive do
              :release -> :ok
            end
          end

          {:ok, state}
        end
      )

    pending = Task.async(fn -> Client.read_view(client(channel), @session) end)
    assert_receive {:blocked, pid}

    assert {:error, %{code: :overflow}} =
             Duplex.received(channel, JSON.encode!(hd(@fixture["saved"])))

    send(pid, :release)
    assert {:error, _} = Task.await(pending)
    assert_receive :channel_closed
    refute_receive {:wire, _}
  end

  test "failed checkpoint storage retains the saved cursor and closes pending work" do
    on_event = fn notice, live ->
      case observer(notice, live) do
        {:ok, %{action: :save}, _} ->
          {:error, %DASP.Error{code: :storage, message: "Store failed."}}

        result ->
          result
      end
    end

    channel = channel(handler_state: start(0), on_event: on_event)
    c = client(channel)
    opening = Task.async(fn -> Client.open(c, @session) end)
    q = request()

    assert :ok =
             Duplex.received(
               channel,
               JSON.encode!(
                 event("session.opened", Map.put(@session, "cursor", 0), q["requestid"])
               )
             )

    assert {:ok, _} = Task.await(opening)
    pending = Task.async(fn -> Client.read_view(c, @session) end)
    _ = request()

    assert {:error, %{code: :storage}} =
             Duplex.received(channel, JSON.encode!(hd(@fixture["saved"])))

    assert {:error, %{code: :storage}} = Task.await(pending)
    assert %{phase: :closed, checkpoint: %{"cursor" => 0}} = Duplex.state(channel)
    assert_receive :channel_closed
  end

  test "invalid replay context is rejected before the receive callback" do
    owner = self()

    channel =
      channel(
        on_event: fn notice, state ->
          send(owner, {:notice, notice})
          {:ok, state}
        end
      )

    pending = Task.async(fn -> Client.read_updates(client(channel), @session, 0, 1) end)
    q = request()

    reply =
      event(
        "updates",
        %{
          "session_id" => @session["session_id"],
          "after" => 1,
          "next" => 1,
          "head" => 1,
          "events" => []
        },
        q["requestid"]
      )

    assert {:error, %{code: :replay}} = Duplex.received(channel, JSON.encode!(reply))
    assert {:error, %{code: :replay}} = Task.await(pending)
    refute_receive {:notice, {:received, _, _}}
  end

  test "cancelling a pending open closes the connection" do
    channel = channel()
    opening = Task.async(fn -> Client.open(client(channel), @session) end)
    q = request()
    Duplex.cancel(channel, [q["requestid"]])
    assert {:error, %{code: :resync}} = Task.await(opening)
    assert_receive :channel_closed
  end

  test "request tracking cannot exceed its connection limit" do
    channel = channel(max_tracked_requests: 1)
    c = client(channel)
    pending = Task.async(fn -> Client.read_view(c, @session) end)
    _ = request()
    assert {:error, %{code: :overflow}} = Client.read_view(c, @session)
    assert {:error, %{code: :overflow}} = Task.await(pending)
    assert_receive :channel_closed
  end
end
