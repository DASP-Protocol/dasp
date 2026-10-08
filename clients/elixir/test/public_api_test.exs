defmodule DASP.PublicAPITest do
  use ExUnit.Case, async: true
  alias DASP.TestSocketServer, as: Server
  @source "urn:example:client:one"
  @host "urn:example:host:one"
  @session %{
    "session_id" => "assistant-1",
    "actor_id" => "actor-1",
    "profile" => %{"id" => "urn:profile:test", "version" => "1"}
  }
  defp opts(extra \\ []) do
    Keyword.merge(
      [
        source: @source,
        host_source: @host,
        allow_insecure: true,
        setup: fn info ->
          case List.keyfind(info.headers, "x-test-selection", 0) do
            {"x-test-selection", "draft-01"} -> :ok
            _ -> :refused
          end
        end,
        validate_profile: fn _ -> true end,
        close_timeout: 50
      ],
      extra
    )
  end

  defp server(extra \\ []) do
    s = Server.start(extra)
    on_exit(fn -> Server.stop(s) end)
    s
  end

  defp client(extra \\ [], server_opts \\ []) do
    {pid, url, _, _} = server(server_opts)
    {:ok, c} = DASP.connect(url, opts(extra))

    on_exit(fn ->
      try do
        GenServer.stop(c.pid)
      catch
        :exit, _ -> :ok
      end
    end)

    {pid, c}
  end

  defp open(c) do
    signal = DASP.Signal.SessionOpen.new!(@session, source: @source)

    assert {:ok, %Jido.Signal{type: "dasp.v1.session.opened"}} =
             DASP.request(c, signal, timeout: 1000)
  end

  defp command(id \\ "purchase-123") do
    DASP.Signal.Command.new!(
      %{
        "session_id" => "assistant-1",
        "command_id" => id,
        "name" => "task.run",
        "input" => %{"task" => "Find a flight"}
      },
      source: @source
    )
  end

  defp event(kind, data, extensions \\ %{}) do
    Map.merge(
      %{
        "specversion" => "1.0",
        "id" => "event-#{System.unique_integer([:positive])}",
        "source" => @host,
        "type" => "dasp.v1.#{kind}",
        "datacontenttype" => "application/json",
        "data" => data
      },
      extensions
    )
  end

  defp progress do
    event("progress", %{
      "session_id" => "assistant-1",
      "command_id" => nil,
      "name" => "task.progress",
      "payload" => %{}
    })
  end

  defp update(seq) do
    event("update", %{
      "session_id" => "assistant-1",
      "sequence" => seq,
      "kind" => "application",
      "command_id" => nil,
      "payload" => %{"name" => "task.changed", "data" => %{}}
    })
  end

  defp receipt(request, disposition \\ "accepted") do
    data = %{
      "session_id" => "assistant-1",
      "command_id" => request["data"]["command_id"],
      "disposition" => disposition,
      "admission_sequence" => 1,
      "error" => nil
    }

    data =
      if disposition == "rejected",
        do: %{
          data
          | "admission_sequence" => nil,
            "error" => %{"code" => "limit", "message" => "Limit reached", "retryable" => false}
        },
        else: data

    event("receipt", data, %{"requestid" => request["requestid"]})
  end

  defp take_request(server, kind) do
    receive do
      {:frame, ^server, 1, wire} ->
        e = JSON.decode!(wire)
        if e["type"] == "dasp.v1.#{kind}", do: e, else: take_request(server, kind)
    after
      1000 -> flunk("Request did not arrive: #{kind}")
    end
  end

  test "all 14 native signal modules use static data schemas and ordinary signals" do
    modules = [
      DASP.Signal.SessionOpen,
      DASP.Signal.SessionOpened,
      DASP.Signal.Command,
      DASP.Signal.Receipt,
      DASP.Signal.Update,
      DASP.Signal.Progress,
      DASP.Signal.ViewRead,
      DASP.Signal.View,
      DASP.Signal.UpdatesRead,
      DASP.Signal.Updates,
      DASP.Signal.OutcomeRead,
      DASP.Signal.Outcome,
      DASP.Signal.ResyncRequired,
      DASP.Signal.Failure
    ]

    fixtures =
      Path.expand("../../../specification/draft-01/examples/counter.json", __DIR__)
      |> File.read!()
      |> JSON.decode!()

    assert length(Enum.uniq(Enum.map(modules, & &1.type()))) == 14

    for mod <- modules do
      assert mod.datacontenttype() == "application/json"
      assert mod.default_source() == nil
      assert mod.dataschema() == nil
      matching = Enum.filter(fixtures, &(&1["type"] == mod.type()))
      assert matching != []

      for e <- matching do
        assert {:ok, %Jido.Signal{} = s} = mod.new(e["data"], source: e["source"])
        assert s.type == e["type"]
        assert s.data == e["data"]
        assert {:ok, _} = mod.validate_data(e["data"])
        assert mod.new!(e["data"], source: e["source"]).data == e["data"]
        assert {:error, _} = mod.new(Map.put(e["data"], "unknown", true), source: e["source"])
      end
    end

    assert {:error, _} = DASP.Signal.Command.new(%{session_id: "one"}, source: @source)

    assert {:error, _} =
             DASP.Signal.Command.new(
               %{
                 "session_id" => "one",
                 "command_id" => "c",
                 "name" => "task.run",
                 "input" => %{"n" => 1.5}
               },
               source: @source
             )
  end

  test "setup gates core traffic and unverified transport is refused" do
    {pid, url, _, _} = server()

    assert {:error, %DASP.Error{code: :configuration}} =
             DASP.connect(url, opts(allow_insecure: false))

    assert {:error, %DASP.Error{code: :configuration}} =
             DASP.connect(url, opts(tls_options: [verify: :verify_none]))

    assert {:error, %DASP.Error{code: :setup}} =
             DASP.connect(url, opts(setup: fn _ -> :refused end))

    refute_receive {:frame, ^pid, 1, _}
    {_, url, _, _} = server()

    assert {:error, %DASP.Error{code: :timeout}} =
             DASP.connect(
               url,
               opts(
                 setup_timeout: 10,
                 setup: fn _ ->
                   Process.sleep(100)
                   :ok
                 end
               )
             )
  end

  test "connecting caller death stops blocked setup and closes the socket" do
    {server, url, _, _} = server()
    parent = self()

    owner =
      spawn(fn ->
        DASP.connect(
          url,
          opts(
            setup_timeout: 5000,
            setup: fn _ ->
              send(parent, {:setup_started, self()})

              receive do
                :release -> :ok
              end
            end
          )
        )
      end)

    on_exit(fn -> Process.exit(owner, :kill) end)
    assert_receive {:setup_started, worker}, 1000
    on_exit(fn -> Process.exit(worker, :kill) end)
    worker_ref = Process.monitor(worker)
    owner_ref = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_ref, :process, ^owner, :killed}, 1000
    assert_receive {:DOWN, ^worker_ref, :process, ^worker, _}, 1000
    assert_receive {:server_closed, ^server}, 1000
  end

  test "successful startup keeps the connecting caller's lifetime monitor" do
    {server, url, _, _} = server()
    parent = self()

    owner =
      spawn(fn ->
        result = DASP.connect(url, opts())
        send(parent, {:connected, result})

        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> Process.exit(owner, :kill) end)
    assert_receive {:connected, {:ok, client}}, 1000
    ref = Process.monitor(client.pid)
    send(owner, :finish)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 1000
    assert_receive {:server_closed, ^server}, 1000
  end

  test "concurrent requests correlate out of order, and rejected receipts are replies" do
    {server, c} = client()
    open(c)
    original = command()
    {:ok, first} = DASP.request_async(c, original)
    {:ok, second} = DASP.request_async(c, command("purchase-124"))
    q1 = take_request(server, "command")
    q2 = take_request(server, "command")
    assert q1["data"] == original.data
    refute q1["id"] == original.id
    Server.send_event(server, receipt(q2, "rejected"))
    Server.send_event(server, receipt(q1))
    assert {:ok, %Jido.Signal{data: %{"disposition" => "accepted"}}} = DASP.await(c, first)
    assert {:ok, %Jido.Signal{data: %{"disposition" => "rejected"}}} = DASP.await(c, second)
    assert {:error, %DASP.Error{code: :request}} = DASP.await(c, second)
    assert :ok = DASP.close(c)
  end

  test "protocol Failure is a signal and differs from a local transport error" do
    {server, c} = client()
    open(c)
    {:ok, ref} = DASP.request_async(c, command())
    q = take_request(server, "command")

    failure =
      event(
        "failure",
        %{"error" => %{"code" => "denied", "message" => "Denied", "retryable" => false}},
        %{"requestid" => q["requestid"]}
      )

    Server.send_event(server, failure)
    assert {:ok, %Jido.Signal{type: "dasp.v1.failure"}} = DASP.await(c, ref)
    {:ok, ref} = DASP.request_async(c, command())
    Server.drop(server)
    assert {:error, %DASP.Error{code: :transport}} = DASP.await(c, ref)
  end

  test "attempt context is fresh, timeouts have one result, and late replies are discarded" do
    {server, c} = client()
    open(c)
    saved = command()
    saved = %{saved | extensions: %{"requestid" => "caller-saved", "daspauthority" => "grant-1"}}
    {:ok, first} = DASP.request_async(c, saved, timeout: 20)
    q1 = take_request(server, "command")
    assert q1["requestid"] != "caller-saved"
    assert q1["daspauthority"] == "grant-1"
    assert {:error, %DASP.Error{code: :timeout}} = DASP.await(c, first)
    Server.send_event(server, receipt(q1))
    {:ok, second} = DASP.request_async(c, saved)
    q2 = take_request(server, "command")
    assert q2["data"] == q1["data"]
    refute q2["requestid"] == q1["requestid"]
    Server.send_event(server, receipt(q2, "duplicate"))
    assert {:ok, %Jido.Signal{data: %{"disposition" => "duplicate"}}} = DASP.await(c, second)
    refute_receive {:frame, ^server, 1, _}
  end

  test "async results remain bounded until consumed" do
    {server, c} = client(max_pending_requests: 1)
    open(c)
    {:ok, ref} = DASP.request_async(c, command())
    q = take_request(server, "command")
    Server.send_event(server, receipt(q))
    assert {:error, %DASP.Error{code: :overflow}} = DASP.request_async(c, command())
    assert {:ok, _} = DASP.await(c, ref)
    assert {:ok, _} = DASP.request_async(c, command(), timeout: 10)
  end

  test "subscribe before open, bounded demand, timeout, and exact event identity" do
    {server, c} = client()
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)
    assert {:error, %DASP.Error{code: :wait_timeout}} = DASP.next(sub, timeout: 5)
    e = update(1)
    Server.send_event(server, e)
    assert {:ok, signal} = DASP.next(sub)
    assert DASP.Wire.to_map!(signal) == e
    assert :ok = DASP.unsubscribe(sub)
    assert :ok = DASP.close(c)
  end

  test "slow subscriptions overflow explicitly, without filling the consumer mailbox" do
    {server, c} = client(max_subscription_messages: 1)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)
    for _ <- 1..3, do: Server.send_event(server, progress())
    # A server ping gives an ordered barrier after all preceding data.
    Server.send_frame(server, 9, "barrier")
    assert_receive {:frame, ^server, 10, "barrier"}, 1000
    assert {:error, %DASP.Error{code: :delivery_overflow}} = DASP.next(sub)
    refute_receive %Jido.Signal{}
    {:ok, fresh} = DASP.subscribe(c, session_id: "assistant-1")
    e = progress()
    Server.send_event(server, e)
    assert {:ok, _} = DASP.next(fresh)
    assert :ok = DASP.unsubscribe(sub)
    assert :ok = DASP.unsubscribe(fresh)
  end

  test "streams compose with Enum.take and release a shared subscription on halt" do
    {server, c} = client(max_subscriptions: 1)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)
    Server.send_event(server, progress())
    assert [%Jido.Signal{}] = sub |> DASP.signals() |> Enum.take(1)
    assert map_size(:sys.get_state(c.pid).subscriptions) == 0
    assert {:ok, next} = DASP.subscribe(c, session_id: "assistant-1")
    assert :ok = DASP.unsubscribe(next)
    assert Process.alive?(c.pid)
  end

  test "failed connections raise during stream enumeration" do
    {server, c} = client()
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)
    Server.drop(server)
    assert_raise DASP.Error, fn -> Enum.take(DASP.signals(sub), 1) end
    assert map_size(:sys.get_state(c.pid).subscriptions) == 0
  end

  test "stream activation is lazy and a consumer exit releases its subscription" do
    {_, c} = client(max_subscriptions: 1)
    stream = DASP.signals(c, session_id: "assistant-1")
    assert map_size(:sys.get_state(c.pid).subscriptions) == 0
    parent = self()

    consumer =
      spawn(fn ->
        {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
        send(parent, {:subscribed, self()})
        DASP.next(sub)
      end)

    assert_receive {:subscribed, ^consumer}
    Process.exit(consumer, :kill)
    monitor = Process.monitor(consumer)
    assert_receive {:DOWN, ^monitor, :process, ^consumer, _}
    wait_until(fn -> map_size(:sys.get_state(c.pid).subscriptions) == 0 end)
    assert is_function(stream, 2)
    assert {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    DASP.unsubscribe(sub)
  end

  test "real WebSocket fragments, masked client writes, ping, and close work" do
    {server, c} = client()
    open(c)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    wire = JSON.encode!(progress())
    {one, two} = String.split_at(wire, 20)
    Server.send_frame(server, 1, one, false)
    Server.send_frame(server, 9, "probe")
    Server.send_frame(server, 0, two)
    assert_receive {:frame, ^server, 10, "probe"}
    assert {:ok, %Jido.Signal{type: "dasp.v1.progress"}} = DASP.next(sub)
    assert :ok = DASP.close(c)
    assert_receive {:frame, ^server, 8, _}
  end

  test "binary frames and incomplete assembly overflow close the connection" do
    {server, c} = client()
    open(c)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    Server.send_frame(server, 2, "binary")
    assert {:error, %DASP.Error{code: :invalid_event}} = DASP.next(sub)
    {server, c} = client(max_buffer_bytes: 1000)
    open(c)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    Server.send_frame(server, 1, String.duplicate("x", 1500), false)
    assert {:error, %DASP.Error{code: :overflow}} = DASP.next(sub)
  end

  test "drain waits for pending replies and keeps a fixed deadline" do
    {server, c} = client()
    open(c)
    {:ok, ref} = DASP.request_async(c, command())
    q = take_request(server, "command")
    task = Task.async(fn -> DASP.drain(c, timeout: 1000) end)
    wait_until(fn -> :sys.get_state(c.pid).conn.drain_at != nil end)
    assert {:error, %DASP.Error{code: :draining}} = DASP.request(c, command())
    Server.send_event(server, receipt(q))
    assert {:ok, _} = DASP.await(c, ref)
    assert :ok = Task.await(task)
    {server, c} = client([], ignore_close: true)
    open(c)
    {:ok, _} = DASP.request_async(c, command())
    take_request(server, "command")
    assert {:error, %DASP.Error{code: :drain_timeout}} = DASP.drain(c, timeout: 30)
  end

  test "session actor and profile stay fixed, and invalid reply context fails all requests" do
    {server, c} = client()
    open(c)

    changed =
      DASP.Signal.SessionOpen.new!(Map.put(@session, "actor_id", "another"), source: @source)

    assert {:error, %DASP.Error{code: :correlation}} = DASP.request(c, changed)
    {:ok, ref} = DASP.request_async(c, command())
    q = take_request(server, "command")
    Server.send_event(server, Map.put(receipt(q), "source", "urn:other:host"))
    assert {:error, %DASP.Error{code: :correlation}} = DASP.await(c, ref)
  end

  test "supervised runtime uses the same API with a temporary child" do
    {_, url, _, _} = server()
    spec = DASP.child_spec(Keyword.put(opts(), :url, url))
    assert spec.restart == :temporary
    {:ok, pid} = start_supervised(spec)
    {:ok, c} = DASP.connection(pid)
    open(c)
    assert :ok = DASP.close(c)
  end

  test "functional engine uses the existing process and returns local events" do
    {server, url, _, _} = server()
    {:ok, conn} = DASP.Connection.connect(url, opts())
    assert conn.owner == self()
    assert :unknown = DASP.Connection.stream(conn, {:unrelated, self()})
    signal = DASP.Signal.SessionOpen.new!(@session, source: @source)
    {:ok, conn, ref} = DASP.Connection.request(conn, signal)

    {conn, [{:reply, ^ref, {:ok, %Jido.Signal{type: "dasp.v1.session.opened"}}}]} =
      receive_engine(conn)

    {:ok, conn, ref} = DASP.Connection.request(conn, command(), timeout: 10)
    take_request(server, "command")
    Process.sleep(15)

    {:ok, conn, [{:reply, ^ref, {:error, %DASP.Error{code: :timeout}}}]} =
      DASP.Connection.tick(conn)

    assert conn.phase == :open
    {:ok, _, [{:error, %DASP.Error{code: :closed}}]} = DASP.Connection.close(conn)
  end

  test "verified TLS accepts a trusted host and refuses unknown roots or another hostname" do
    cert = Path.expand("support/tls/localhost-cert.pem", __DIR__)
    key = Path.expand("support/tls/localhost-key.pem", __DIR__)

    ca =
      Path.expand("support/tls/ca-cert.pem", __DIR__)
      |> File.read!()
      |> :public_key.pem_decode()
      |> Enum.map(fn {_, der, _} -> der end)

    {_, url, _, _} = server(tls: true, certfile: cert, keyfile: key)
    {:ok, c} = DASP.connect(url, opts(allow_insecure: false, tls_options: [cacerts: ca]))
    open(c)
    assert :ok = DASP.close(c)

    ExUnit.CaptureLog.capture_log(fn ->
      {_, url, _, _} = server(tls: true, certfile: cert, keyfile: key)

      assert {:error, %DASP.Error{code: :transport}} =
               DASP.connect(url, opts(allow_insecure: false))

      {_, url, _, _} = server(tls: true, certfile: cert, keyfile: key)
      url = String.replace(url, "localhost", "127.0.0.1")

      assert {:error, %DASP.Error{code: :transport}} =
               DASP.connect(url, opts(allow_insecure: false, tls_options: [cacerts: ca]))
    end)

    assert {:error, %DASP.Error{code: :configuration}} =
             DASP.connect(url, opts(tls_options: [server_name_indication: :disable]))
  end

  test "ping bytes sent with the upgrade response are kept" do
    {server, c} = client([], initial: Server.frame(9, "early-ping", true))
    assert_receive {:frame, ^server, 10, "early-ping"}, 1000
    open(c)
  end

  test "subscription byte bounds and unrelated session filters are enforced" do
    {server, c} = client(max_subscription_bytes: 10)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    {:ok, other} = DASP.subscribe(c, session_id: "other")
    open(c)
    Server.send_event(server, progress())
    Server.send_frame(server, 9, "byte-barrier")
    assert_receive {:frame, ^server, 10, "byte-barrier"}, 1000
    assert {:error, %DASP.Error{code: :delivery_overflow}} = DASP.next(sub)
    assert {:error, %DASP.Error{code: :wait_timeout}} = DASP.next(other, timeout: 5)
  end

  test "application work in a stream consumer does not block socket ping handling" do
    {server, c} = client()
    open(c)
    owner = self()

    consumer =
      spawn(fn ->
        {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
        send(owner, :activated)

        Enum.each(DASP.signals(sub), fn _ ->
          send(owner, :application_busy)

          receive do
            :continue -> :ok
          end
        end)
      end)

    assert_receive :activated
    Server.send_event(server, progress())
    assert_receive :application_busy
    Server.send_frame(server, 9, "during-application-work")
    assert_receive {:frame, ^server, 10, "during-application-work"}, 1000
    Process.exit(consumer, :kill)
  end

  test "fixed recovery head, ordered replay, saved identity, and applied cursor remain explicit" do
    {server, c} = client([], head: 2)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)

    view =
      event("view", Map.merge(@session, %{"cursor" => 0, "state" => %{}}), %{
        "requestid" => "saved-view"
      })

    {:ok, saved} = DASP.Checkpoint.from_view(view, fn _ -> true end)

    read =
      DASP.Signal.UpdatesRead.new!(%{"session_id" => "assistant-1", "after" => 0, "limit" => 2},
        source: @source
      )

    {:ok, ref} = DASP.request_async(c, read, replay_head: 2)
    q = take_request(server, "updates.read")
    replay = [update(1), update(2)]
    Server.send_event(server, update(3))

    Server.send_event(
      server,
      event(
        "updates",
        %{
          "session_id" => "assistant-1",
          "after" => 0,
          "next" => 2,
          "head" => 3,
          "events" => replay
        },
        %{"requestid" => q["requestid"]}
      )
    )

    {:ok, page} = DASP.await(c, ref)
    assert saved["cursor"] == 0
    assert page.data["events"] == replay

    {:ok, applied} =
      DASP.Checkpoint.apply_updates(saved, page.data["events"], fn state, _ -> state end, fn _ ->
        true
      end)

    assert applied["cursor"] == 2
    {:ok, pushed} = DASP.next(sub)
    assert pushed.data["sequence"] == 3
    assert applied["cursor"] == 2
    {:ok, _} = DASP.request_async(c, read, replay_head: 2)
    q = take_request(server, "updates.read")
    # A newer request remains bounded by the caller's fixed recovery head.
    bad =
      event(
        "updates",
        %{
          "session_id" => "assistant-1",
          "after" => 0,
          "next" => 1,
          "head" => 1,
          "events" => [hd(replay)]
        },
        %{"requestid" => q["requestid"]}
      )

    Server.send_event(server, bad)
    assert {:error, %DASP.Error{code: :continuity}} = DASP.next(sub)
  end

  test "resync cancels recovery reads and requires reopen without making a local host event" do
    {server, c} = client([], head: 2)
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    open(c)

    read =
      DASP.Signal.UpdatesRead.new!(%{"session_id" => "assistant-1", "after" => 0, "limit" => 2},
        source: @source
      )

    {:ok, ref} = DASP.request_async(c, read, replay_head: 2)
    q = take_request(server, "updates.read")

    resync =
      event("resync.required", %{
        "session_id" => "assistant-1",
        "reason" => "overflow",
        "head" => 2
      })

    Server.send_event(server, resync)
    assert {:error, %DASP.Error{code: :resync}} = DASP.await(c, ref)
    assert {:ok, signal} = DASP.next(sub)
    assert DASP.Wire.to_map!(signal) == resync
    assert {:error, %DASP.Error{code: :session}} = DASP.request(c, command())

    Server.send_event(
      server,
      event(
        "updates",
        %{
          "session_id" => "assistant-1",
          "after" => 0,
          "next" => 2,
          "head" => 2,
          "events" => [update(1), update(2)]
        },
        %{"requestid" => q["requestid"]}
      )
    )

    open(c)
    assert {:error, %DASP.Error{code: :wait_timeout}} = DASP.next(sub, timeout: 5)
  end

  test "concurrent drain callers share the first physical deadline" do
    {server, c} = client([], ignore_close: true)
    open(c)
    {:ok, _} = DASP.request_async(c, command(), timeout: 2000)
    take_request(server, "command")
    first = Task.async(fn -> DASP.drain(c, timeout: 50) end)
    wait_until(fn -> :sys.get_state(c.pid).conn.drain_at != nil end)
    before = System.monotonic_time(:millisecond)
    assert {:error, %DASP.Error{code: :drain_timeout}} = DASP.drain(c, timeout: 2000)
    assert System.monotonic_time(:millisecond) - before < 500
    assert {:error, %DASP.Error{code: :drain_timeout}} = Task.await(first)
    assert_receive {:server_closed, ^server}, 1000
  end

  test "a functional socket reply after a deadline cannot win a timer race" do
    {server, url, _, _} = server()
    {:ok, conn} = DASP.Connection.connect(url, opts())

    {:ok, conn, _} =
      DASP.Connection.request(conn, DASP.Signal.SessionOpen.new!(@session, source: @source))

    {conn, [_]} = receive_engine(conn)
    {:ok, conn, ref} = DASP.Connection.request(conn, command(), timeout: 10)
    q = take_request(server, "command")
    Process.sleep(15)
    Server.send_event(server, receipt(q))
    {conn, [{:reply, ^ref, {:error, %DASP.Error{code: :timeout}}}]} = receive_engine(conn)
    {:ok, _, _} = DASP.Connection.close(conn)
  end

  test "a request caller exit releases request and dispatch capacity" do
    {server, c} = client(max_pending_requests: 1)
    open(c)
    parent = self()

    owner =
      spawn(fn ->
        {:ok, ref} = DASP.request_async(c, command())
        send(parent, {:accepted, ref})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:accepted, _}
    q = take_request(server, "command")
    Process.exit(owner, :kill)
    wait_until(fn -> map_size(:sys.get_state(c.pid).requests) == 0 end)
    assert [{:queue, 0, 0}] = :ets.lookup(c.budget, :queue)
    Server.send_event(server, receipt(q))
    {:ok, ref} = DASP.request_async(c, command())
    q = take_request(server, "command")
    Server.send_event(server, receipt(q, "duplicate"))
    assert {:ok, _} = DASP.await(c, ref)
  end

  test "hard drain closes the physical socket while a validation callback blocks" do
    parent = self()

    validator = fn signal ->
      if signal.type == "dasp.v1.command" do
        send(parent, :validator_blocked)
        Process.sleep(:infinity)
      end

      true
    end

    {server, c} = client(validate_profile: validator)
    open(c)
    task = Task.async(fn -> DASP.request(c, command()) end)
    assert_receive :validator_blocked
    started = System.monotonic_time(:millisecond)
    assert {:error, %DASP.Error{code: :drain_timeout}} = DASP.drain(c.pid, timeout: 30)
    assert System.monotonic_time(:millisecond) - started < 500
    assert {:error, %DASP.Error{code: :closed}} = Task.await(task)
    assert_receive {:server_closed, ^server}, 1000
    refute Process.alive?(c.pid)
  end

  test "waiting requests have bounded local queue count and bytes" do
    {_, c} = client(max_queued_bytes: 10)

    assert {:error, %DASP.Error{code: :overflow}} =
             DASP.request(c, DASP.Signal.SessionOpen.new!(@session, source: @source))

    parent = self()

    validator = fn signal ->
      if signal.type == "dasp.v1.command" do
        send(parent, :queue_blocked)
        Process.sleep(:infinity)
      end

      true
    end

    {_, c} = client(validate_profile: validator, max_queued_messages: 1)
    open(c)
    first = Task.async(fn -> DASP.request(c, command()) end)
    assert_receive :queue_blocked
    second = Task.async(fn -> DASP.request(c, command()) end)
    wait_until(fn -> :ets.lookup_element(c.budget, :queue, 2) == 1 end)
    assert {:error, %DASP.Error{code: :overflow}} = DASP.request(c, command())
    DASP.drain(c, timeout: 20)
    Task.await(first)
    Task.await(second)
  end

  test "request options count toward the dispatch byte bound" do
    {_, c} = client(max_queued_bytes: 1024)
    :sys.suspend(c.pid)
    parent = self()

    try do
      spawn(fn ->
        send(
          parent,
          {:queued_result, DASP.request_async(c, command(), bad: String.duplicate("x", 3000))}
        )
      end)

      assert_receive {:queued_result, {:error, %DASP.Error{code: :overflow}}}, 1000
      assert [{:queue, 0, 0}] = :ets.lookup(c.budget, :queue)
    after
      :sys.resume(c.pid)
    end
  end

  for operation <- [:close, :drain] do
    test "#{operation} retains its physical guard after the caller times out" do
      {_, c} = client([close_timeout: 300], ignore_close: true)
      socket = :sys.get_state(c.pid).conn.socket.http |> Mint.HTTP.get_socket()
      :sys.suspend(c.pid)
      before = MapSet.new(Process.list())
      parent = self()

      caller =
        spawn(fn ->
          result = lifecycle_result(unquote(operation), c)
          send(parent, {:lifecycle_result, result})
        end)

      guard = deadline_guard(before, caller, c.pid)
      :erlang.suspend_process(guard)
      monitor = Process.monitor(c.pid)

      try do
        assert_receive {:lifecycle_result, {:error, %DASP.Error{}}}, 1000
        assert Process.alive?(c.pid)
        :erlang.resume_process(guard)
        assert_receive {:DOWN, ^monitor, :process, _, :killed}, 1000
        wait_until(fn -> match?({:error, _}, :inet.peername(socket)) end)
      after
        Process.exit(guard, :kill)
        Process.exit(c.pid, :kill)
      end
    end
  end

  defp lifecycle_result(:close, client), do: DASP.close(client)
  defp lifecycle_result(:drain, client), do: DASP.drain(client, timeout: 300)

  defp deadline_guard(before, caller, owner, attempts \\ 100) do
    guard =
      Enum.find(Process.list(), fn pid ->
        pid != caller and not MapSet.member?(before, pid) and
          Process.info(pid, :monitors) == {:monitors, [{:process, owner}]}
      end)

    cond do
      guard ->
        guard

      attempts > 0 ->
        Process.sleep(1)
        deadline_guard(before, caller, owner, attempts - 1)

      true ->
        flunk("Physical deadline guard did not start.")
    end
  end

  test "profile rejection prevents outgoing traffic and fails an incoming profile mismatch" do
    {server, c} =
      client(validate_profile: fn s -> s.type not in ["dasp.v1.command", "dasp.v1.progress"] end)

    open(c)
    take_request(server, "session.open")
    assert {:error, %DASP.Error{code: :profile}} = DASP.request(c, command())
    refute_receive {:frame, ^server, 1, _}
    {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
    Server.send_event(server, progress())
    assert {:error, %DASP.Error{code: :profile}} = DASP.next(sub)
  end

  test "actor and profile mismatches in an open reply fail the connection" do
    for key <- ["actor_id", "profile"] do
      {server, c} = client([], auto_open: false)
      {:ok, ref} = DASP.request_async(c, DASP.Signal.SessionOpen.new!(@session, source: @source))
      q = take_request(server, "session.open")

      replacement =
        if key == "actor_id",
          do: "other-actor",
          else: %{"id" => "urn:other:profile", "version" => "1"}

      data = @session |> Map.put("cursor", 0) |> Map.put(key, replacement)
      Server.send_event(server, event("session.opened", data, %{"requestid" => q["requestid"]}))
      assert {:error, %DASP.Error{code: :correlation}} = DASP.await(c, ref)
    end
  end

  test "the complete existing-owner example uses one process and bounded local delivery" do
    {server, url, _, _} = server()
    {:ok, owner} = DASP.Examples.SocketOwner.start_link(url, opts())

    on_exit(fn ->
      try do
        GenServer.stop(owner)
      catch
        :exit, _ -> :ok
      end
    end)

    assert {:ok, %Jido.Signal{type: "dasp.v1.session.opened"}} =
             DASP.Examples.SocketOwner.request(
               owner,
               DASP.Signal.SessionOpen.new!(@session, source: @source)
             )

    Server.send_event(server, progress())
    wait_until(fn -> :sys.get_state(owner).count == 1 end)
    assert {:ok, %Jido.Signal{type: "dasp.v1.progress"}} = DASP.Examples.SocketOwner.next(owner)
    assert :empty = DASP.Examples.SocketOwner.next(owner)
    assert :sys.get_state(owner).connection.owner == owner
  end

  test "stream enumeration continues after its local waiting timeout" do
    {server, c} = client()
    open(c)
    parent = self()

    consumer =
      Task.async(fn ->
        {:ok, sub} = DASP.subscribe(c, session_id: "assistant-1")
        send(parent, :stream_active)
        Enum.take(DASP.signals(sub), 1)
      end)

    assert_receive :stream_active
    Process.sleep(10_050)
    assert Task.yield(consumer, 0) == nil
    Server.send_event(server, progress())
    assert [%Jido.Signal{type: "dasp.v1.progress"}] = Task.await(consumer, 1000)
    assert map_size(:sys.get_state(c.pid).subscriptions) == 0
  end

  test "core identifiers and CloudEvents extension names reject trailing line breaks" do
    data = command().data

    assert {:error, _} =
             DASP.Signal.Command.new(Map.put(data, "session_id", "assistant-1\n"),
               source: @source
             )

    assert {:error, _} =
             DASP.Signal.Command.new(Map.put(data, "name", "task.run\n"), source: @source)

    signal = %{command() | extensions: %{"requestid" => "attempt-1", "extra\n" => true}}
    assert {:error, %DASP.Error{code: :invalid_event}} = DASP.encode(signal)
  end

  defp receive_engine(conn) do
    receive do
      message ->
        case DASP.Connection.stream(conn, message) do
          :unknown -> receive_engine(conn)
          {:ok, next, []} -> receive_engine(next)
          {:ok, next, events} -> {next, events}
        end
    after
      1000 -> flunk("Engine received no socket event")
    end
  end

  defp wait_until(fun, attempts \\ 100)
  defp wait_until(_, 0), do: flunk("State did not change")

  defp wait_until(fun, attempts) do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(5)
          wait_until(fun, attempts - 1)
        )
  end
end
