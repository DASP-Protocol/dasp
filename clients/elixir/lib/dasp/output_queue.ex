defmodule DASP.OutputQueue do
  @moduledoc """
  Bounded logical host output, before delivery encryption.
  enqueue/3 returns {:ok, {:queued | :dropped, queue}}; only progress can be dropped.
  take/1 returns {:ok, {delivery_or_nil, queue}}. One active lease remains charged
  until complete/2. A lease completion is not admission, completion, or a cursor.
  The driver supplies current permission, framing, health checks, and resync.
  """
  alias DASP.{Error, Wire}

  defstruct lanes: [],
            active: nil,
            count: 0,
            bytes: 0,
            ordinary_count: 0,
            ordinary_bytes: 0,
            serial: 0,
            burst: 0,
            closed: false,
            limits: %{}

  @controls ~w(dasp.v1.session.opened dasp.v1.receipt dasp.v1.failure dasp.v1.resync.required)
  @outputs @controls ++
             ~w(dasp.v1.update dasp.v1.progress dasp.v1.view dasp.v1.updates dasp.v1.outcome)

  def new(opts \\ []) do
    Wire.protect(fn ->
      max_messages = Keyword.get(opts, :max_messages, 128)
      max_bytes = Keyword.get(opts, :max_bytes, 2_097_152)

      limits =
        Map.new(
          Keyword.merge(
            [
              max_messages: max_messages,
              max_bytes: max_bytes,
              max_session_messages: min(32, max_messages),
              max_session_bytes: min(524_288, max_bytes),
              reserved_control_messages: 8,
              reserved_control_bytes: 65_536,
              max_control_burst: 8
            ],
            opts
          )
        )

      if Enum.any?(
           Map.values(limits),
           &(not is_integer(&1) or &1 < 1 or &1 > DASP.JSON.max_integer())
         ) or
           limits.max_session_messages > limits.max_messages or
           limits.max_session_bytes > limits.max_bytes or
           limits.reserved_control_messages >= limits.max_messages or
           limits.reserved_control_bytes >= limits.max_bytes,
         do: raise(error(:configuration, "Invalid output queue limits."))

      %__MODULE__{limits: limits}
    end)
  end

  def usage(q), do: %{messages: q.count, bytes: q.bytes}

  def enqueue(q, value, failure_session_id \\ nil) do
    Wire.protect(fn ->
      available!(q)
      event = Wire.to_signal!(value)
      wire = Wire.encode!(event)

      if event.type not in @outputs,
        do: raise(error(:configuration, "The queue accepts host output only."))

      session =
        if event.type == "dasp.v1.failure", do: failure_session_id, else: event.data["session_id"]

      if not DASP.Signal.Fields.identifier?(session),
        do: raise(error(:configuration, "Supply the output session identity."))

      if q.serial == DASP.JSON.max_integer(),
        do: raise(error(:overflow, "Output lease identities are exhausted."))

      entry = %{
        token: q.serial + 1,
        session_id: session,
        wire: wire,
        event: event,
        bytes: byte_size(wire),
        control: event.type in @controls
      }

      lane = q.lanes |> List.keyfind(session, 0, {session, []}) |> elem(1)
      last = List.last(lane)

      replace =
        if event.type == "dasp.v1.progress" and last != nil and last.event.type == event.type and
             last.event.data["command_id"] == event.data["command_id"] and
             last.event.data["name"] == event.data["name"],
           do: last

      cond do
        fits?(q, entry, replace) ->
          next = if replace, do: charge(q, replace, -1), else: q
          entries = if replace, do: Enum.drop(lane, -1) ++ [entry], else: lane ++ [entry]

          lanes =
            if List.keymember?(q.lanes, session, 0),
              do: List.keyreplace(q.lanes, session, 0, {session, entries}),
              else: q.lanes ++ [{session, entries}]

          {:queued, charge(%{next | serial: q.serial + 1, lanes: lanes}, entry, 1)}

        event.type == "dasp.v1.progress" ->
          {:dropped, q}

        true ->
          raise(error(:overflow, "Output capacity exceeded; resync or close is required."))
      end
    end)
  end

  def take(q) do
    Wire.protect(fn ->
      available!(q)

      if q.active != nil or q.lanes == [] do
        {nil, q}
      else
        control = Enum.find(q.lanes, fn {_, [entry | _]} -> entry.control end)
        ordinary = Enum.find(q.lanes, fn {_, [entry | _]} -> not entry.control end)

        {session, [entry | rest]} =
          if control != nil and (ordinary == nil or q.burst < q.limits.max_control_burst),
            do: control,
            else: ordinary

        lanes = List.keydelete(q.lanes, session, 0)
        lanes = if rest == [], do: lanes, else: lanes ++ [{session, rest}]
        burst = if entry.control, do: min(q.burst + 1, q.limits.max_control_burst), else: 0
        delivery = Map.take(entry, [:token, :session_id, :wire, :event])
        {delivery, %{q | lanes: lanes, active: entry, burst: burst}}
      end
    end)
  end

  def complete(q, token) do
    Wire.protect(fn ->
      available!(q)

      if q.active == nil or q.active.token != token,
        do: raise(error(:configuration, "Output lease does not match the active write."))

      %{charge(q, q.active, -1) | active: nil}
    end)
  end

  def discard_updates(q, session) do
    Wire.protect(fn ->
      available!(q)
      entries = q.lanes |> List.keyfind(session, 0, {session, []}) |> elem(1)

      {dropped, kept} =
        Enum.split_with(entries, &(&1.event.type in ~w(dasp.v1.update dasp.v1.progress)))

      next = Enum.reduce(dropped, q, &charge(&2, &1, -1))

      lanes =
        if kept == [],
          do: List.keydelete(q.lanes, session, 0),
          else: List.keyreplace(q.lanes, session, 0, {session, kept})

      {length(dropped), %{next | lanes: lanes}}
    end)
  end

  def close(q),
    do: %{
      q
      | closed: true,
        lanes: [],
        active: nil,
        count: 0,
        bytes: 0,
        ordinary_count: 0,
        ordinary_bytes: 0
    }

  defp fits?(q, entry, old) do
    old_count = if old, do: 1, else: 0
    old_bytes = if old, do: old.bytes, else: 0
    lane = q.lanes |> List.keyfind(entry.session_id, 0, {entry.session_id, []}) |> elem(1)

    session =
      if q.active != nil and q.active.session_id == entry.session_id,
        do: [q.active | lane],
        else: lane

    q.count + 1 - old_count <= q.limits.max_messages and
      q.bytes + entry.bytes - old_bytes <= q.limits.max_bytes and
      length(session) + 1 - old_count <= q.limits.max_session_messages and
      Enum.sum(Enum.map(session, & &1.bytes)) + entry.bytes - old_bytes <=
        q.limits.max_session_bytes and
      (entry.control or
         (q.ordinary_count + 1 - old_count <=
            q.limits.max_messages - q.limits.reserved_control_messages and
            q.ordinary_bytes + entry.bytes - old_bytes <=
              q.limits.max_bytes - q.limits.reserved_control_bytes))
  end

  defp charge(q, entry, direction) do
    ordinary = if entry.control, do: 0, else: direction

    %{
      q
      | count: q.count + direction,
        bytes: q.bytes + direction * entry.bytes,
        ordinary_count: q.ordinary_count + ordinary,
        ordinary_bytes: q.ordinary_bytes + ordinary * entry.bytes
    }
  end

  defp available!(%{closed: true}), do: raise(error(:closed, "The output queue is closed."))
  defp available!(_), do: :ok
  defp error(code, message), do: %Error{code: code, message: message}
end
