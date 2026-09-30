defmodule DASP.Duplex do
  @moduledoc """
  Request dispatcher for an authenticated, selected duplex channel.
  Obtain channel/1 once, use transport/1 for DASP.Client, and pass original
  authenticated/decrypted core JSON to received/2. send hands off a message;
  it must not wait for a reply. on_event runs in order and can save a checkpoint.
  Return {:ok, state, cancel: ids} to cancel recovery reads during resync.
  Callbacks must not await new client requests. No socket or handshake is supplied.
  """
  use GenServer
  alias DASP.{Error, Wire}

  defmodule Channel do
    @moduledoc false
    defstruct [:pid, :budget, :max_messages, :max_bytes]
  end

  @replies %{
    "dasp.v1.session.open" => "dasp.v1.session.opened",
    "dasp.v1.command" => "dasp.v1.receipt",
    "dasp.v1.view.read" => "dasp.v1.view",
    "dasp.v1.updates.read" => "dasp.v1.updates",
    "dasp.v1.outcome.read" => "dasp.v1.outcome"
  }

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def channel(pid), do: GenServer.call(pid, :channel)
  def state(%Channel{pid: pid}), do: GenServer.call(pid, :state)

  def transport(%Channel{} = c),
    do: fn wire, timeout -> exchange(c, {:request, wire, timeout}, wire) end

  def received(%Channel{} = c, wire), do: exchange(c, {:received, wire}, wire)
  def cancel(%Channel{pid: pid}, ids), do: GenServer.cast(pid, {:cancel, ids})

  def close(%Channel{} = c) do
    :ets.insert(c.budget, {:closed, true})
    GenServer.cast(c.pid, {:close, error(:closed, "The channel is closed.")})
  end

  defp exchange(c, message, wire) when is_binary(wire) do
    cond do
      :ets.lookup_element(c.budget, :closed, 2) ->
        {:error, error(:closed, "The channel is closed.")}

      byte_size(wire) > 1_048_576 ->
        close(c)
        {:error, error(:overflow, "Core message byte limit exceeded.")}

      true ->
        [count, bytes] = :ets.update_counter(c.budget, :queue, [{2, 1}, {3, byte_size(wire)}])

        if count > c.max_messages or bytes > c.max_bytes do
          :ets.update_counter(c.budget, :queue, [{2, -1}, {3, -byte_size(wire)}])
          close(c)
          {:error, error(:overflow, "Duplex queue limit exceeded.")}
        else
          GenServer.call(c.pid, message, :infinity)
        end
    end
  catch
    :exit, _ -> {:error, error(:transport, "Channel process stopped.")}
    :error, :badarg -> {:error, error(:transport, "Channel process stopped.")}
  end

  @impl true
  def init(opts) do
    o =
      Map.new(
        Keyword.merge(
          [
            max_queued_messages: 100,
            max_queued_bytes: 1_048_576,
            max_pending_requests: 100,
            max_tracked_requests: 4096,
            handler_state: nil,
            on_event: fn _, s -> {:ok, s} end
          ],
          opts
        )
      )

    if not is_function(o[:send], 1) or not is_function(o[:close], 0) or
         not is_function(o.on_event, 2) or not is_binary(o[:host_source]) or
         not Regex.match?(~r/^[a-z][a-z0-9+.-]*:\S+$/i, o.host_source) or
         Enum.any?(
           [
             :max_queued_messages,
             :max_queued_bytes,
             :max_pending_requests,
             :max_tracked_requests
           ],
           fn k -> not is_integer(o[k]) or o[k] < 1 end
         ) do
      {:stop, error(:configuration, "Invalid duplex options.")}
    else
      budget = :ets.new(__MODULE__, [:public, :set, write_concurrency: true])
      :ets.insert(budget, [{:queue, 0, 0}, {:closed, false}])

      {:ok,
       %{
         options: o,
         handler_state: o.handler_state,
         budget: budget,
         pending: %{},
         seen: MapSet.new(),
         cancelled: %{},
         failure: nil
       }}
    end
  end

  @impl true
  def handle_call(:channel, _, s) do
    {:reply,
     %Channel{
       pid: self(),
       budget: s.budget,
       max_messages: s.options.max_queued_messages,
       max_bytes: s.options.max_queued_bytes
     }, s}
  end

  def handle_call(:state, _, s), do: {:reply, s.handler_state, s}

  def handle_call({:request, wire, timeout}, from, s) do
    result =
      protect(fn ->
        available!(s)

        if not is_integer(timeout) or timeout < 1 or timeout > 2_147_483_647,
          do: raise(error(:configuration, "Invalid request deadline."))

        event = Wire.decode!(wire)
        id = event.extensions["requestid"]

        if not Map.has_key?(@replies, event.type) or MapSet.member?(s.seen, id),
          do: raise(error(:correlation, "Invalid or repeated request."))

        if map_size(s.pending) >= s.options.max_pending_requests or
             MapSet.size(s.seen) >= s.options.max_tracked_requests,
           do: raise(error(:overflow, "Request tracking limit exceeded."))

        if not Process.alive?(elem(from, 0)),
          do: raise(error(:timeout, "Request caller stopped before send."))

        next = observe!(s, {:sent, event, wire})
        available!(next)

        case next.options.send.(wire) do
          :ok -> :ok
          _ -> raise(error(:transport, "Channel send failed; send must return :ok."))
        end

        p = %{
          event: event,
          from: from,
          monitor: Process.monitor(elem(from, 0)),
          timer: Process.send_after(self(), {:deadline, id}, timeout)
        }

        %{next | seen: MapSet.put(next.seen, id), pending: Map.put(next.pending, id, p)}
      end)

    release(s, wire)

    case result do
      {:ok, next} -> {:noreply, next}
      {:error, e} -> {:reply, {:error, e}, close_state(s, e)}
    end
  end

  def handle_call({:received, wire}, _, s) do
    result =
      protect(fn ->
        available!(s)
        event = Wire.decode!(wire)

        if event.source != s.options.host_source,
          do: raise(error(:correlation, "Unexpected host source."))

        if event.type in ["dasp.v1.update", "dasp.v1.progress", "dasp.v1.resync.required"] do
          observe!(s, {:received, event, wire})
        else
          id = event.extensions["requestid"]

          if Map.has_key?(s.cancelled, id) do
            if event.type not in [s.cancelled[id], "dasp.v1.failure"],
              do: raise(error(:correlation, "Invalid cancelled reply type."))

            s
          else
            p = s.pending[id] || raise(error(:correlation, "Reply has no pending request."))
            reply_context!(p.event, event)
            next = observe!(s, {:received, event, wire})

            if Map.has_key?(next.pending, id) do
              cleanup(p)
              GenServer.reply(p.from, {:ok, wire})
            end

            %{next | pending: Map.delete(next.pending, id)}
          end
        end
      end)

    release(s, wire)

    case result do
      {:ok, next} -> {:reply, :ok, next}
      {:error, e} -> {:reply, {:error, e}, close_state(s, e)}
    end
  end

  @impl true
  def handle_cast({:cancel, ids}, s),
    do: {:noreply, cancel_state(s, ids, error(:resync, "Recovery request was cancelled."))}

  def handle_cast({:close, e}, s), do: {:noreply, close_state(s, e)}
  @impl true
  def handle_info({:deadline, id}, s), do: {:noreply, timed_out(s, id)}

  def handle_info({:DOWN, ref, :process, _, _}, s) do
    id = Enum.find_value(s.pending, fn {id, p} -> if p.monitor == ref, do: id end)
    {:noreply, if(id, do: timed_out(s, id), else: s)}
  end

  defp timed_out(s, id) do
    case s.pending[id] do
      nil ->
        s

      %{event: %{type: "dasp.v1.session.open"}} ->
        close_state(s, error(:timeout, "Open reply deadline expired."))

      _ ->
        next = cancel_state(s, [id], error(:timeout, "Reply deadline expired."))

        case protect(fn -> observe!(next, {:timeout, id}) end) do
          {:ok, observed} -> observed
          {:error, e} -> close_state(next, e)
        end
    end
  end

  defp cancel_state(s, ids, e) do
    Enum.reduce(ids, s, fn id, acc ->
      case acc.pending[id] do
        nil ->
          acc

        %{event: %{type: "dasp.v1.session.open"}} ->
          close_state(acc, e)

        p ->
          cleanup(p)
          GenServer.reply(p.from, {:error, e})

          %{
            acc
            | pending: Map.delete(acc.pending, id),
              cancelled: Map.put(acc.cancelled, id, @replies[p.event.type])
          }
      end
    end)
  end

  defp close_state(%{failure: e} = s, _) when not is_nil(e), do: s

  defp close_state(s, e) do
    :ets.insert(s.budget, {:closed, true})

    Enum.each(s.pending, fn {_, p} ->
      cleanup(p)
      GenServer.reply(p.from, {:error, e})
    end)

    next = %{s | failure: e, pending: %{}}
    _ = protect(fn -> s.options.close.() end)

    case protect(fn -> observe!(next, {:closed, e}) end) do
      {:ok, observed} -> observed
      _ -> next
    end
  end

  defp available!(s) do
    if s.failure || :ets.lookup_element(s.budget, :closed, 2),
      do: raise(s.failure || error(:closed, "The channel is closed."))
  end

  defp observe!(s, notice) do
    case s.options.on_event.(notice, s.handler_state) do
      {:ok, next} ->
        %{s | handler_state: next}

      {:ok, next, opts} ->
        cancel_state(
          %{s | handler_state: next},
          Keyword.get(opts, :cancel, []),
          error(:resync, "Recovery request was cancelled.")
        )

      {:error, %Error{} = e} ->
        raise e

      _ ->
        raise(error(:transport, "Event callback must return a state or DASP.Error."))
    end
  end

  defp reply_context!(_, %{type: "dasp.v1.failure"}), do: :ok

  defp reply_context!(q, event) do
    d = event.data

    if event.type != @replies[q.type] or d["session_id"] != q.data["session_id"] or
         (Map.has_key?(q.data, "command_id") and d["command_id"] != q.data["command_id"]) or
         (Map.has_key?(q.data, "actor_id") and
            (d["actor_id"] != q.data["actor_id"] or d["profile"] != q.data["profile"])),
       do: raise(error(:correlation, "Reply differs from request context."))

    if event.type == "dasp.v1.updates" do
      if d["after"] != q.data["after"] or d["after"] > d["head"] or
           length(d["events"]) > q.data["limit"] or
           (d["after"] < d["head"] and d["events"] == []),
         do: raise(error(:replay, "Invalid replay page bounds."))

      next =
        Enum.reduce(d["events"], d["after"], fn raw, cursor ->
          update = Wire.to_signal!(raw)

          if update.source != event.source or update.data["session_id"] != d["session_id"] or
               update.data["sequence"] != cursor + 1 or update.data["sequence"] > d["head"],
             do: raise(error(:replay, "Invalid replay event context."))

          update.data["sequence"]
        end)

      if d["next"] != next, do: raise(error(:replay, "Invalid replay next cursor."))
    end
  end

  defp cleanup(p) do
    Process.cancel_timer(p.timer)
    Process.demonitor(p.monitor, [:flush])
  end

  defp release(s, wire),
    do: :ets.update_counter(s.budget, :queue, [{2, -1}, {3, -byte_size(wire)}])

  defp error(code, message), do: %Error{code: code, message: message}

  defp protect(fun) do
    {:ok, fun.()}
  rescue
    e in Error -> {:error, e}
    _ -> {:error, error(:transport, "Channel callback failed.")}
  end
end
