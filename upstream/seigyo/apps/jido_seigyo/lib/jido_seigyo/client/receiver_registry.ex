defmodule Jido.Seigyo.Client.ReceiverRegistry do
  @moduledoc false

  @type kind :: :progress | :updates
  @type t :: %{
          receivers: %{kind() => %{optional(String.t()) => pid()}},
          monitors: %{optional(reference()) => {kind(), String.t(), pid()}}
        }

  @spec new() :: t()
  def new do
    %{receivers: %{progress: %{}, updates: %{}}, monitors: %{}}
  end

  @spec get(t(), kind(), String.t()) :: pid() | nil
  def get(registry, kind, session_id) do
    get_in(registry, [:receivers, kind, session_id])
  end

  @spec put(t(), kind(), String.t(), pid()) :: t()
  def put(registry, kind, session_id, receiver)
      when kind in [:progress, :updates] and is_binary(session_id) and is_pid(receiver) do
    registry = drop(registry, kind, session_id)
    monitor = Process.monitor(receiver)

    %{
      registry
      | receivers: Map.update!(registry.receivers, kind, &Map.put(&1, session_id, receiver)),
        monitors: Map.put(registry.monitors, monitor, {kind, session_id, receiver})
    }
  end

  @spec pop_monitor(t(), reference(), pid()) ::
          {nil | {kind(), String.t(), pid()}, t()}
  def pop_monitor(registry, monitor, receiver) when is_reference(monitor) and is_pid(receiver) do
    case Map.pop(registry.monitors, monitor) do
      {nil, _monitors} ->
        {nil, registry}

      {{kind, session_id, ^receiver} = entry, monitors} ->
        receivers =
          if get(registry, kind, session_id) == receiver do
            Map.update!(registry.receivers, kind, &Map.delete(&1, session_id))
          else
            registry.receivers
          end

        {entry, %{registry | receivers: receivers, monitors: monitors}}

      {_entry, _monitors} ->
        {nil, registry}
    end
  end

  defp drop(registry, kind, session_id) do
    monitors =
      Enum.reduce(registry.monitors, registry.monitors, fn
        {monitor, {^kind, ^session_id, _receiver}}, acc ->
          Process.demonitor(monitor, [:flush])
          Map.delete(acc, monitor)

        _entry, acc ->
          acc
      end)

    %{
      registry
      | receivers: Map.update!(registry.receivers, kind, &Map.delete(&1, session_id)),
        monitors: monitors
    }
  end
end
