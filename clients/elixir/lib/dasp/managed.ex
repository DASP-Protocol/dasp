defmodule DASP.Managed do
  @moduledoc false
  use GenServer
  alias DASP.{Connection, Error, Subscription}

  @limits [
    max_subscriptions: 100,
    max_subscription_messages: 100,
    max_subscription_bytes: 1_048_576,
    max_queued_messages: 100,
    max_queued_bytes: 2_097_152
  ]

  def child_spec(opts),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, restart: :temporary}

  def start_link(opts), do: start(opts, true)
  def start(opts), do: start(opts, false)

  defp start(opts, linked) do
    if is_list(opts) and Keyword.keyword?(opts) do
      {local, engine} = Keyword.split(opts, Keyword.keys(@limits) ++ [:url, :name])
      limits = Map.new(Keyword.merge(@limits, Keyword.drop(local, [:url, :name])))

      if Enum.all?(limits, fn {_, v} -> is_integer(v) and v in 1..2_147_483_647 end) do
        args = {Keyword.get(local, :url), engine, limits, if(linked, do: nil, else: self())}
        options = if local[:name], do: [name: local[:name]], else: []

        if linked,
          do: GenServer.start_link(__MODULE__, args, options),
          else: GenServer.start(__MODULE__, args, options)
      else
        {:error, error(:configuration, "Invalid managed client bounds.")}
      end
    else
      {:error, error(:configuration, "Supply keyword options.")}
    end
  end

  def handle(%DASP{} = client), do: {:ok, client}

  def handle(client) do
    # Read only the immutable public handle. A blocked owner cannot delay drain
    # before its independent deadline guard has started.
    pid = GenServer.whereis(client)

    with true <- is_pid(pid),
         {:dictionary, entries} <- Process.info(pid, :dictionary),
         {_, %DASP{} = handle} <- List.keyfind(entries, {__MODULE__, :handle}, 0) do
      {:ok, handle}
    else
      _ -> {:error, error(:closed, "The managed client is unavailable.")}
    end
  rescue
    _ -> {:error, error(:configuration, "Supply a local DASP handle, PID, or process name.")}
  end

  def request(client, signal, opts, mode) do
    with {:ok, handle} <- handle(client),
         {:ok, reservation} <- reserve(handle, signal, opts, mode) do
      try do
        call(handle, {:request, reservation, signal, opts, mode})
      after
        release(handle, reservation)
      end
    end
  end

  defp reserve(handle, signal, opts, mode) do
    if :ets.lookup(handle.budget, :draining) == [{:draining, true}],
      do: raise(error(:draining, "The client is draining."))

    reservation = make_ref()
    bytes = :erlang.external_size({:request, reservation, signal, opts, mode})
    [count, size] = :ets.update_counter(handle.budget, :queue, [{2, 1}, {3, bytes}])

    if count > handle.max_queued_messages or size > handle.max_queued_bytes do
      :ets.update_counter(handle.budget, :queue, [{2, -1}, {3, -bytes}])
      {:error, error(:overflow, "Local request queue exceeds its bound.")}
    else
      :ets.insert(handle.budget, {reservation, bytes})
      {:ok, reservation}
    end
  rescue
    e in Error -> {:error, e}
    ArgumentError -> {:error, error(:closed, "The client is closed.")}
  end

  defp release(handle, reservation) do
    case :ets.take(handle.budget, reservation) do
      [{^reservation, bytes}] ->
        :ets.update_counter(handle.budget, :queue, [{2, -1}, {3, -bytes}])

      [] ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end

  def call(%DASP{pid: pid}, message), do: call(pid, message)

  def call(pid, message) do
    GenServer.call(pid, message, :infinity)
  catch
    :exit, _ -> {:error, error(:closed, "The client process stopped. Admission can be unknown.")}
  end

  def subscribe(client, opts), do: call(client, {:subscribe, opts})
  def next(%Subscription{} = sub, opts), do: call(sub.client, {:next, sub.ref, opts})
  def unsubscribe(%Subscription{} = sub), do: call(sub.client, {:unsubscribe, sub.ref})
  def await(client, ref, opts), do: call(client, {:await, ref, opts})

  def close(client) do
    with {:ok, handle} <- handle(client) do
      case :ets.lookup(handle.budget, :close_result) do
        [{:close_result, result}] ->
          result

        [] ->
          :ets.insert_new(handle.budget, {:close_deadline, now() + handle.close_timeout})
          expires = :ets.lookup_element(handle.budget, :close_deadline, 2)
          guard = watchdog(handle.pid, expires)

          try do
            result = GenServer.call(handle.pid, :close, max(1, expires - now()))
            send(guard, :stop)
            result
          catch
            :exit, _ -> {:error, error(:close_timeout, "Physical close deadline expired.")}
          end
      end
    end
  rescue
    ArgumentError -> :ok
  end

  def drain(client, opts) do
    with {:ok, timeout} <- waiting_timeout(opts), {:ok, handle} <- handle(client) do
      case :ets.lookup(handle.budget, :drain_result) do
        [{:drain_result, result}] -> result
        [] -> drain_wait(handle, opts, timeout)
      end
    end
  end

  defp drain_wait(handle, opts, timeout) do
    :ets.insert_new(handle.budget, {:drain_deadline, now() + timeout})
    expires = :ets.lookup_element(handle.budget, :drain_deadline, 2)
    :ets.insert(handle.budget, {:draining, true})
    owner = handle.pid
    guard = watchdog(owner, expires)

    try do
      result = GenServer.call(owner, {:drain, opts, expires}, max(1, expires - now()))
      send(guard, :stop)
      result
    catch
      :exit, _ ->
        {:error, error(:drain_timeout, "Drain deadline expired. Admission can be unknown.")}
    end
  rescue
    ArgumentError -> {:error, error(:closed, "The client is closed.")}
  end

  @impl true
  def init({url, opts, limits, owner}) do
    owner_ref = if owner, do: Process.monitor(owner)
    guard = if owner, do: watchdog(self(), :infinity, owner)

    connection =
      try do
        Connection.connect(url, opts)
      after
        if guard, do: send(guard, :stop)
      end

    case connection do
      {:ok, conn} ->
        budget = :ets.new(__MODULE__, [:public, :set, write_concurrency: true])
        :ets.insert(budget, {:queue, 0, 0})

        handle = %DASP{
          pid: self(),
          budget: budget,
          max_queued_messages: limits.max_queued_messages,
          max_queued_bytes: limits.max_queued_bytes,
          close_timeout: conn.options.close_timeout
        }

        Process.put({__MODULE__, :handle}, handle)

        {:ok,
         %{
           conn: conn,
           handle: handle,
           limits: limits,
           requests: %{},
           subscriptions: %{},
           monitors: %{},
           timer: nil,
           drain_waiters: [],
           close_waiters: [],
           owner_ref: owner_ref
         }}

      {:error, e} ->
        {:stop, e}
    end
  end

  @impl true
  def handle_call({:request, reservation, signal, opts, mode}, from, s) do
    release(s.handle, reservation)
    # Async terminal results occupy the same bound until the owner takes them.
    if map_size(s.requests) >= s.conn.options.max_pending_requests do
      {:reply, {:error, error(:overflow, "Local request result bound reached.")}, s}
    else
      case Connection.request(s.conn, signal, opts) do
        {:ok, conn, ref} ->
          pid = elem(from, 0)
          p = %{owner: pid, from: if(mode == :sync, do: from), result: nil, waiter: nil}
          s = monitor(%{s | conn: conn, requests: Map.put(s.requests, ref, p)}, pid) |> schedule()
          if mode == :sync, do: {:noreply, s}, else: {:reply, {:ok, ref}, s}

        {:error, conn, e} ->
          s = %{s | conn: conn}
          s = if e.code == :transport, do: fail_connection(s, e), else: s
          {:reply, {:error, e}, schedule(s)}
      end
    end
  end

  def handle_call({:await, ref, opts}, from, s) do
    case s.requests[ref] do
      %{owner: owner} = p when owner == elem(from, 0) ->
        cond do
          p.from != nil or p.waiter != nil ->
            {:reply, {:error, error(:request, "A result waiter is already active.")}, s}

          p.result != nil ->
            {:reply, p.result, drop_request(s, ref)}

          true ->
            case waiting_timeout(opts) do
              {:ok, timeout} ->
                token = make_ref()
                timer = Process.send_after(self(), {:await_timeout, ref, token}, timeout)
                {:noreply, put_in(s, [:requests, ref, :waiter], {from, timer, token})}

              e ->
                {:reply, e, s}
            end
        end

      _ ->
        {:reply, {:error, error(:request, "Unknown local request or wrong owner.")}, s}
    end
  end

  def handle_call({:subscribe, opts}, from, s) do
    with {:ok, sid} <- subscription_options(opts),
         true <- s.conn.phase == :open and s.conn.drain_at == nil,
         true <- map_size(s.subscriptions) < s.limits.max_subscriptions do
      ref = make_ref()
      owner = elem(from, 0)

      sub = %{
        owner: owner,
        session_id: sid,
        queue: :queue.new(),
        count: 0,
        bytes: 0,
        waiter: nil,
        failure: nil
      }

      s = monitor(%{s | subscriptions: Map.put(s.subscriptions, ref, sub)}, owner)
      {:reply, {:ok, %Subscription{client: s.handle, ref: ref, owner: owner}}, s}
    else
      {:error, e} ->
        {:reply, {:error, e}, s}

      false ->
        {:reply,
         {:error,
          s.conn.failure ||
            error(:overflow, "The client is closed, draining, or at its subscription bound.")}, s}
    end
  end

  def handle_call({:next, ref, opts}, from, s) do
    case s.subscriptions[ref] do
      %{owner: owner} = sub when owner == elem(from, 0) ->
        case waiting_timeout(opts) do
          {:ok, timeout} -> next_call(s, ref, sub, from, timeout)
          e -> {:reply, e, s}
        end

      _ ->
        {:reply, {:error, error(:subscription, "Unknown subscription or wrong consumer.")}, s}
    end
  end

  def handle_call({:unsubscribe, ref}, from, s) do
    case s.subscriptions[ref] do
      %{owner: owner} = sub when owner == elem(from, 0) ->
        if sub.waiter,
          do: finish_waiter(sub.waiter, {:error, error(:subscription, "Subscription released.")})

        {:reply, :ok, drop_subscription(s, ref)}

      nil ->
        {:reply, :ok, s}

      _ ->
        {:reply, {:error, error(:ownership, "Release the subscription in its consumer process.")},
         s}
    end
  end

  def handle_call({:drain, opts, expires}, from, s) do
    conn = %{s.conn | drain_at: s.conn.drain_at || expires}

    case Connection.drain(conn, opts) do
      {:ok, conn, events} ->
        s = dispatch(%{s | conn: conn, drain_waiters: [from | s.drain_waiters]}, events)
        {:noreply, schedule(s) |> finish_lifecycle()}

      {:error, _, e} ->
        {:reply, {:error, e}, s}
    end
  end

  def handle_call(:close, from, s) do
    {:ok, conn, events} = Connection.closing(s.conn)
    s = dispatch(%{s | conn: conn, close_waiters: [from | s.close_waiters]}, events)
    {:noreply, schedule(s) |> finish_lifecycle()}
  end

  defp next_call(s, _, %{waiter: waiter}, _, _) when not is_nil(waiter),
    do: {:reply, {:error, error(:subscription, "Only one demand can wait on a subscription.")}, s}

  defp next_call(s, _, %{failure: e}, _, _) when not is_nil(e), do: {:reply, {:error, e}, s}

  defp next_call(s, ref, sub, from, timeout) do
    case :queue.out(sub.queue) do
      {{:value, {signal, bytes}}, queue} ->
        sub = %{sub | queue: queue, count: sub.count - 1, bytes: sub.bytes - bytes}
        {:reply, {:ok, signal}, put_in(s, [:subscriptions, ref], sub)}

      {:empty, _} ->
        token = make_ref()
        timer = Process.send_after(self(), {:subscription_timeout, ref, token}, timeout)
        {:noreply, put_in(s, [:subscriptions, ref, :waiter], {from, timer, token})}
    end
  end

  @impl true
  def handle_info(:deadline, s) do
    {:ok, conn, events} = Connection.tick(s.conn)

    {:noreply,
     dispatch(%{s | conn: conn, timer: nil}, events) |> schedule() |> finish_lifecycle()}
  end

  def handle_info({:subscription_timeout, ref, token}, s) do
    case s.subscriptions[ref] do
      %{waiter: {from, _, ^token}} = sub ->
        GenServer.reply(
          from,
          {:error, error(:wait_timeout, "No signal arrived within the local wait time.")}
        )

        {:noreply, put_in(s, [:subscriptions, ref], %{sub | waiter: nil})}

      _ ->
        {:noreply, s}
    end
  end

  def handle_info({:await_timeout, ref, token}, s) do
    case s.requests[ref] do
      %{waiter: {from, _, ^token}} ->
        GenServer.reply(
          from,
          {:error, error(:wait_timeout, "The result wait expired. The request remains pending.")}
        )

        {:noreply, put_in(s, [:requests, ref, :waiter], nil)}

      _ ->
        {:noreply, s}
    end
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_ref: ref} = s), do: {:stop, :normal, s}

  def handle_info({:DOWN, ref, :process, pid, _}, s) do
    if s.monitors[pid] == ref do
      s = %{s | monitors: Map.delete(s.monitors, pid)}

      s =
        Enum.reduce(s.subscriptions, s, fn {id, sub}, acc ->
          if sub.owner == pid, do: drop_subscription(acc, id), else: acc
        end)

      s =
        Enum.reduce(s.requests, s, fn {id, p}, acc ->
          if p.owner == pid do
            {:ok, conn, events} = Connection.cancel(acc.conn, id)
            dispatch(%{drop_request(acc, id) | conn: conn}, events)
          else
            acc
          end
        end)

      {:noreply, schedule(s)}
    else
      {:noreply, s}
    end
  end

  def handle_info(message, s) do
    # Expire requests before accepting a reply which is already past its deadline.
    {:ok, conn, due} = Connection.tick(s.conn)
    s = dispatch(%{s | conn: conn}, due)

    case Connection.stream(s.conn, message) do
      :unknown ->
        {:noreply, schedule(s) |> finish_lifecycle()}

      {:ok, conn, events} ->
        {:noreply, dispatch(%{s | conn: conn}, events) |> schedule() |> finish_lifecycle()}
    end
  end

  defp dispatch(s, events), do: Enum.reduce(events, s, &event/2)

  defp event({:reply, ref, result}, s) do
    case s.requests[ref] do
      nil ->
        s

      %{from: from} when not is_nil(from) ->
        GenServer.reply(from, result)
        drop_request(s, ref)

      %{waiter: waiter} when not is_nil(waiter) ->
        finish_waiter(waiter, result)
        drop_request(s, ref)

      p ->
        put_in(s, [:requests, ref], %{p | result: result})
    end
  end

  defp event({:signal, signal}, s) do
    bytes = byte_size(DASP.Wire.encode!(signal))

    Enum.reduce(s.subscriptions, s, fn {ref, sub}, acc ->
      cond do
        sub.failure != nil or sub.session_id != signal.data["session_id"] ->
          acc

        sub.waiter != nil ->
          finish_waiter(sub.waiter, {:ok, signal})
          put_in(acc, [:subscriptions, ref], %{sub | waiter: nil})

        sub.count >= s.limits.max_subscription_messages or
            sub.bytes + bytes > s.limits.max_subscription_bytes ->
          e =
            error(
              :delivery_overflow,
              "Local subscription overflow. Recover from the saved applied cursor."
            )

          put_in(acc, [:subscriptions, ref], %{
            sub
            | failure: e,
              queue: :queue.new(),
              count: 0,
              bytes: 0
          })

        true ->
          put_in(acc, [:subscriptions, ref], %{
            sub
            | queue: :queue.in({signal, bytes}, sub.queue),
              count: sub.count + 1,
              bytes: sub.bytes + bytes
          })
      end
    end)
  end

  defp event({:error, e}, s) do
    Enum.reduce(s.subscriptions, s, fn {ref, sub}, acc ->
      if sub.waiter, do: finish_waiter(sub.waiter, {:error, sub.failure || e})

      put_in(acc, [:subscriptions, ref], %{
        sub
        | failure: sub.failure || e,
          waiter: nil,
          queue: :queue.new(),
          count: 0,
          bytes: 0
      })
    end)
  end

  defp fail_connection(s, e) do
    {:ok, conn, events} = Connection.close(s.conn, e)
    dispatch(%{s | conn: conn}, events)
  end

  defp schedule(s) do
    if s.timer, do: Process.cancel_timer(s.timer)

    timer =
      case Connection.next_timeout(s.conn) do
        :infinity -> nil
        timeout -> Process.send_after(self(), :deadline, timeout)
      end

    %{s | timer: timer}
  end

  defp finish_lifecycle(%{conn: %{phase: :closed}} = s) do
    result = if s.conn.failure.code == :drained, do: :ok, else: {:error, s.conn.failure}
    :ets.insert(s.handle.budget, [{:close_result, :ok}, {:drain_result, result}])
    Enum.each(s.drain_waiters, &GenServer.reply(&1, result))
    Enum.each(s.close_waiters, &GenServer.reply(&1, :ok))
    %{s | drain_waiters: [], close_waiters: []}
  end

  defp finish_lifecycle(s), do: s

  defp watchdog(owner, expires, caller \\ nil) do
    spawn(fn ->
      ref = Process.monitor(owner)
      caller_ref = if caller, do: Process.monitor(caller)
      timeout = if expires == :infinity, do: :infinity, else: max(1, expires - now())

      receive do
        :stop -> :ok
        {:DOWN, ^ref, :process, ^owner, _} -> :ok
        {:DOWN, ^caller_ref, :process, ^caller, _} -> Process.exit(owner, :kill)
      after
        timeout -> Process.exit(owner, :kill)
      end
    end)
  end

  defp monitor(s, pid) do
    if Map.has_key?(s.monitors, pid),
      do: s,
      else: %{s | monitors: Map.put(s.monitors, pid, Process.monitor(pid))}
  end

  defp drop_request(s, ref) do
    p = s.requests[ref]
    if p && p.waiter, do: Process.cancel_timer(elem(p.waiter, 1))
    next = %{s | requests: Map.delete(s.requests, ref)}
    if p, do: unmonitor(next, p.owner), else: next
  end

  defp drop_subscription(s, ref) do
    sub = s.subscriptions[ref]
    if sub && sub.waiter, do: Process.cancel_timer(elem(sub.waiter, 1))
    next = %{s | subscriptions: Map.delete(s.subscriptions, ref)}
    if sub, do: unmonitor(next, sub.owner), else: next
  end

  defp unmonitor(s, pid) do
    if Enum.any?(s.requests, fn {_, p} -> p.owner == pid end) or
         Enum.any?(s.subscriptions, fn {_, p} -> p.owner == pid end) do
      s
    else
      if s.monitors[pid], do: Process.demonitor(s.monitors[pid], [:flush])
      %{s | monitors: Map.delete(s.monitors, pid)}
    end
  end

  defp finish_waiter({from, timer, _}, result) do
    Process.cancel_timer(timer)
    GenServer.reply(from, result)
  end

  defp subscription_options(opts) do
    if is_list(opts) and Keyword.keyword?(opts) and Keyword.keys(opts) == [:session_id] and
         DASP.Signal.Fields.identifier?(opts[:session_id]),
       do: {:ok, opts[:session_id]},
       else: {:error, error(:configuration, "Supply a valid session_id subscription option.")}
  end

  defp waiting_timeout(opts) do
    if is_list(opts) and Keyword.keyword?(opts) and Keyword.keys(opts) -- [:timeout] == [] do
      timeout = Keyword.get(opts, :timeout, 10_000)

      if is_integer(timeout) and timeout in 1..2_147_483_647,
        do: {:ok, timeout},
        else: {:error, error(:configuration, "Supply a positive finite wait timeout.")}
    else
      {:error, error(:configuration, "Unknown wait option.")}
    end
  end

  @impl true
  def terminate(_, s) do
    DASP.WebSocket.close(s.conn.socket)
    :ok
  end

  defp error(code, message), do: %Error{code: code, message: message}
  defp now, do: System.monotonic_time(:millisecond)
end
