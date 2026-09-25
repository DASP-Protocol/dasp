defmodule Jido.Seigyo.Client.ReceiverRegistryTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client.ReceiverRegistry

  test "replacing a receiver removes its old monitor" do
    first = spawn(fn -> Process.sleep(:infinity) end)
    second = spawn(fn -> Process.sleep(:infinity) end)

    registry = ReceiverRegistry.new()
    registry = ReceiverRegistry.put(registry, :updates, "session", first)
    registry = ReceiverRegistry.put(registry, :updates, "session", second)

    assert ReceiverRegistry.get(registry, :updates, "session") == second
    assert map_size(registry.monitors) == 1

    Process.exit(first, :kill)
    refute_receive {:DOWN, _monitor, :process, ^first, _reason}

    Process.exit(second, :kill)
    assert_receive {:DOWN, monitor, :process, ^second, :killed}

    assert {{:updates, "session", ^second}, registry} =
             ReceiverRegistry.pop_monitor(registry, monitor, second)

    assert ReceiverRegistry.get(registry, :updates, "session") == nil
    assert registry.monitors == %{}
  end

  test "progress and update receivers for one Session are independent" do
    receiver = spawn(fn -> Process.sleep(:infinity) end)

    registry =
      ReceiverRegistry.new()
      |> ReceiverRegistry.put(:progress, "session", receiver)
      |> ReceiverRegistry.put(:updates, "session", receiver)

    assert ReceiverRegistry.get(registry, :progress, "session") == receiver
    assert ReceiverRegistry.get(registry, :updates, "session") == receiver
    assert map_size(registry.monitors) == 2

    Process.exit(receiver, :kill)
  end
end
