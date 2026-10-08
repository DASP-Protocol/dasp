defmodule DASP.Live do
  @moduledoc """
  Immutable live recovery for one session on an authenticated, selected connection.
  Serialize sent/received transitions. Save a changed checkpoint before installing
  the returned state. On an error, close the entire connection. This module does
  not establish trust, open sockets, or define encryption setup.
  """
  import DASP.Error, only: [fail: 2]
  alias DASP.{Checkpoint, Client, Wire}

  defstruct [
    :checkpoint,
    :options,
    :target,
    :next_push,
    phase: :inactive,
    action: :none,
    pending: %{},
    seen: MapSet.new(),
    cancelled: MapSet.new(),
    buffer: [],
    buffer_bytes: 0
  ]

  def new(opts) do
    Wire.protect(fn ->
      cp = Keyword.fetch!(opts, :checkpoint)

      options =
        Map.new(
          Keyword.merge(
            [
              page_limit: 100,
              max_buffered_events: 100,
              max_buffered_bytes: 1_048_576,
              max_tracked_requests: 4096
            ],
            opts
          )
        )

      if not is_function(options[:reduce], 2) or not is_function(options[:validate_profile], 1),
        do: fail(:configuration, "Supply reducer and profile validator.")

      Enum.each(
        [:page_limit, :max_buffered_events, :max_buffered_bytes, :max_tracked_requests],
        fn key ->
          value = options[key]

          if not is_integer(value) or value < 1 or value > DASP.JSON.max_integer(),
            do: fail(:configuration, "Invalid live recovery limit.")
        end
      )

      if options.page_limit > 100, do: fail(:configuration, "Page limit exceeds 100.")

      base = %{
        "specversion" => "1.0",
        "id" => "checkpoint",
        "requestid" => "checkpoint",
        "datacontenttype" => "application/json"
      }

      Wire.to_signal!(
        Map.merge(base, %{
          "source" => cp["host_source"],
          "type" => "dasp.v1.view",
          "data" => Map.merge(cp["session"], %{"cursor" => cp["cursor"], "state" => cp["state"]})
        })
      )

      Wire.to_signal!(
        Map.merge(base, %{
          "source" => options[:client_source],
          "type" => "dasp.v1.session.open",
          "data" => cp["session"]
        })
      )

      if not is_map(cp["evidence"]) or
           Enum.any?(cp["evidence"], fn {_, value} ->
             not is_binary(value) and not is_map(value)
           end),
         do: fail(:checkpoint, "Invalid duplicate evidence.")

      %__MODULE__{checkpoint: cp, options: Map.delete(options, :checkpoint)}
    end)
  end

  def pending_open(live) do
    Enum.find_value(live.pending, fn {id, p} ->
      if p.event.type == "dasp.v1.session.open", do: id
    end)
  end

  def next_read(live) do
    if live.phase == :replay and not Enum.any?(live.pending, fn {_, p} -> p.replay end) do
      %{
        "session_id" => live.checkpoint["session"]["session_id"],
        "after" => live.checkpoint["cursor"],
        "limit" => min(live.options.page_limit, live.target - live.checkpoint["cursor"])
      }
    end
  end

  @doc "Track actual outgoing JSON. Mark only recovery reads with replay: true."
  def sent(live, wire, opts \\ []) do
    Wire.protect(fn ->
      open!(live)
      event = Wire.decode!(wire)
      d = event.data
      id = event.extensions["requestid"]

      if is_nil(DASP.Signal.reply_type(event.type)) or event.source != live.options.client_source or
           d["session_id"] != live.checkpoint["session"]["session_id"],
         do: fail(:correlation, "Request differs from the live session context.")

      if MapSet.member?(live.seen, id),
        do: fail(:correlation, "Request ID was already used on this connection.")

      if MapSet.size(live.seen) >= live.options.max_tracked_requests,
        do: fail(:overflow, "Request tracking limit reached; reconnect.")

      phase =
        if event.type == "dasp.v1.session.open" do
          if pending_open(live), do: fail(:live, "Only one open can be pending for this session.")
          if active?(live), do: live.phase, else: :opening
        else
          live.phase
        end

      replay = Keyword.get(opts, :replay, false)

      if replay and
           (event.type != "dasp.v1.updates.read" or live.phase != :replay or
              Enum.any?(live.pending, fn {_, p} -> p.replay end) or
              d["after"] != live.checkpoint["cursor"] or
              d["limit"] > live.options.page_limit),
         do: fail(:replay, "Invalid recovery read or another recovery read is pending.")

      Client.profile!(live.options.validate_profile, event)

      %{
        live
        | phase: phase,
          action: :none,
          seen: MapSet.put(live.seen, id),
          pending: Map.put(live.pending, id, %{event: event, replay: replay})
      }
    end)
  end

  @doc "Feed original core JSON after channel authentication and decryption."
  def received(live, wire) do
    Wire.protect(fn ->
      open!(live)
      event = Wire.decode!(wire)

      if event.source != live.checkpoint["host_source"],
        do: fail(:correlation, "Unexpected host source.")

      receive_event(%{live | action: :none}, event)
    end)
  end

  defp receive_event(live, %{type: type} = event)
       when type in ["dasp.v1.update", "dasp.v1.progress", "dasp.v1.resync.required"] do
    if not active?(live) or event.data["session_id"] != live.checkpoint["session"]["session_id"],
      do: fail(:live, "Push has no active attachment.")

    Client.profile!(live.options.validate_profile, event)

    case type do
      "dasp.v1.resync.required" ->
        {removed, kept} = Enum.split_with(live.pending, fn {_, p} -> p.replay end)

        cancelled =
          Enum.reduce(removed, live.cancelled, fn {id, _}, acc -> MapSet.put(acc, id) end)

        next = %{
          live
          | phase: :inactive,
            buffer: [],
            buffer_bytes: 0,
            cancelled: cancelled,
            pending: Map.new(kept)
        }

        %{next | action: if(pending_open(next), do: :wait_open, else: :reopen)}

      "dasp.v1.progress" ->
        %{live | action: :progress}

      _ ->
        sequence = event.data["sequence"]
        if sequence != live.next_push, do: fail(:gap, "Live push sequence has a gap or repeat.")
        next = %{live | next_push: sequence + 1}

        if live.phase == :replay do
          buffer = live.buffer ++ [event]
          bytes = live.buffer_bytes + byte_size(Wire.encode!(event))

          if length(buffer) > live.options.max_buffered_events or
               bytes > live.options.max_buffered_bytes,
             do: fail(:overflow, "Live recovery buffer limit exceeded; close the connection.")

          %{next | buffer: buffer, buffer_bytes: bytes}
        else
          cp = apply!(live, live.checkpoint, [event])

          %{
            next
            | checkpoint: cp,
              action: if(cp["cursor"] == live.checkpoint["cursor"], do: :none, else: :save)
          }
        end
    end
  end

  defp receive_event(live, event) do
    id = event.extensions["requestid"]

    if MapSet.member?(live.cancelled, id) do
      if event.type not in ["dasp.v1.updates", "dasp.v1.failure"],
        do: fail(:correlation, "Invalid cancelled replay reply type.")

      %{live | action: :discard}
    else
      pending = live.pending[id] || fail(:correlation, "Reply has no pending request.")
      next = %{live | pending: Map.delete(live.pending, id), action: :reply}

      if event.type == "dasp.v1.failure" do
        if pending.event.type == "dasp.v1.session.open" and not active?(live),
          do: %{next | phase: :inactive},
          else: next
      else
        validate_reply!(live, pending.event, event)
        finish_reply(next, event, pending)
      end
    end
  end

  defp validate_reply!(live, request, event) do
    q = request.data
    d = event.data

    if event.type != DASP.Signal.reply_type(request.type) or d["session_id"] != q["session_id"] or
         (Map.has_key?(q, "command_id") and d["command_id"] != q["command_id"]),
       do: fail(:correlation, "Reply differs from request context.")

    Client.profile!(live.options.validate_profile, event)
  end

  defp finish_reply(live, %{type: "dasp.v1.session.opened", data: d}, pending) do
    tuple = Map.delete(d, "cursor")

    if tuple != pending.event.data or tuple != live.checkpoint["session"],
      do: fail(:correlation, "Open reply changed the session tuple.")

    if active?(live) do
      live
    else
      if d["cursor"] < live.checkpoint["cursor"],
        do: fail(:continuity, "Host head is below the saved applied cursor.")

      %{
        live
        | target: d["cursor"],
          next_push: d["cursor"] + 1,
          phase: if(live.checkpoint["cursor"] < d["cursor"], do: :replay, else: :live)
      }
    end
  end

  defp finish_reply(live, %{type: "dasp.v1.updates", data: d} = event, pending) do
    q = pending.event.data
    Client.page!(event, q["after"], q["limit"])

    Enum.each(d["events"], fn input ->
      update = Wire.to_signal!(input)

      if update.source != live.checkpoint["host_source"],
        do: fail(:replay, "Replay event producer differs from the selected host.")

      Client.profile!(live.options.validate_profile, update)
    end)

    if pending.replay do
      if live.phase != :replay or d["head"] < live.target,
        do: fail(:continuity, "Replay lost its captured history boundary.")

      cp = apply!(live, live.checkpoint, d["events"])

      {cp, phase, buffer, bytes} =
        if cp["cursor"] >= live.target do
          {apply!(live, cp, live.buffer), :live, [], 0}
        else
          {cp, :replay, live.buffer, live.buffer_bytes}
        end

      %{
        live
        | checkpoint: cp,
          phase: phase,
          buffer: buffer,
          buffer_bytes: bytes,
          action: if(cp["cursor"] == live.checkpoint["cursor"], do: :reply, else: :save)
      }
    else
      live
    end
  end

  defp finish_reply(live, %{type: "dasp.v1.view", data: d}, _pending) do
    if d["actor_id"] != live.checkpoint["session"]["actor_id"] or
         d["profile"] != live.checkpoint["session"]["profile"],
       do: fail(:correlation, "View changed the session tuple.")

    live
  end

  defp finish_reply(live, _event, _pending), do: live

  def timeout(live, id) do
    Wire.protect(fn ->
      pending = live.pending[id] || fail(:correlation, "Timeout has no pending request.")

      if pending.event.type == "dasp.v1.session.open" do
        close(live)
      else
        %{
          live
          | pending: Map.delete(live.pending, id),
            action: :none,
            cancelled:
              if(pending.replay, do: MapSet.put(live.cancelled, id), else: live.cancelled)
        }
      end
    end)
  end

  def close(live),
    do: %{live | phase: :closed, action: :close, pending: %{}, buffer: [], buffer_bytes: 0}

  defp active?(live), do: live.phase in [:replay, :live]
  defp open!(live), do: if(live.phase == :closed, do: fail(:closed, "The connection is closed."))

  defp apply!(live, cp, events) do
    case Checkpoint.apply_updates(cp, events, live.options.reduce, live.options.validate_profile) do
      {:ok, next} -> next
      {:error, error} -> raise error
    end
  end
end
