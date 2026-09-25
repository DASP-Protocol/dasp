defmodule Jido.Seigyo.Client.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client
  alias Jido.Seigyo.Client.Capabilities
  alias Jido.Seigyo.{Progress, SessionOpen, SessionOpened, Update}

  setup do
    {:ok, capabilities} =
      "principal"
      |> Jido.Seigyo.capabilities()
      |> Capabilities.from_data()

    %{capabilities: capabilities}
  end

  test "an operation requires its operation and Signal capabilities", %{
    capabilities: capabilities
  } do
    assert :ok =
             Capabilities.require_operation(
               capabilities,
               "open",
               SessionOpen.type(),
               SessionOpened.type()
             )

    assert {:error, %Client.Error{kind: :protocol, reason: :unsupported_operation}} =
             Capabilities.require_operation(
               %{capabilities | operations: []},
               "open",
               SessionOpen.type(),
               SessionOpened.type()
             )

    assert {:error, %Client.Error{kind: :protocol, reason: :unsupported_request_signal}} =
             Capabilities.require_operation(
               %{capabilities | request_signal_types: []},
               "open",
               SessionOpen.type(),
               SessionOpened.type()
             )

    assert {:error, %Client.Error{kind: :protocol, reason: :unsupported_result_signal}} =
             Capabilities.require_operation(
               %{capabilities | result_signal_types: []},
               "open",
               SessionOpen.type(),
               SessionOpened.type()
             )
  end

  test "a read operation can omit a request Signal type", %{capabilities: capabilities} do
    assert :ok =
             Capabilities.require_operation(
               capabilities,
               "updates",
               nil,
               Jido.Seigyo.UpdatesPage.type()
             )
  end

  test "a control requires every push Signal capability", %{capabilities: capabilities} do
    assert :ok =
             Capabilities.require_control(
               capabilities,
               "watch_updates",
               [Update.type(), Jido.Seigyo.ResyncRequired.type()]
             )

    assert {:error, %Client.Error{kind: :protocol, reason: :unsupported_control}} =
             Capabilities.require_control(
               %{capabilities | controls: []},
               "watch_progress",
               [Progress.type()]
             )

    assert {:error, %Client.Error{kind: :protocol, reason: :unsupported_push_signal}} =
             Capabilities.require_control(
               %{capabilities | push_signal_types: []},
               "watch_progress",
               [Progress.type()]
             )
  end

  test "capability lists reject duplicate entries" do
    data = Jido.Seigyo.capabilities("principal")

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.update!("operations", &[hd(&1) | &1])
             |> Capabilities.from_data()
  end

  test "the public client covers every advertised coding v1 operation and control" do
    operation_apis = %{
      "open" => {:open, 2},
      "submit" => {:submit_text, 4},
      "updates" => {:updates, 3},
      "history" => {:history, 3},
      "view" => {:view, 3},
      "trace" => {:trace, 4},
      "workspace_changes" => {:workspace_changes, 3},
      "workspaces" => {:workspaces, 2},
      "workspace_configure" => {:configure_workspace, 3},
      "execution_catalog" => {:execution_catalog, 2},
      "configuration" => {:configuration, 3},
      "configuration_history" => {:configuration_history, 3},
      "configure" => {:configure, 4},
      "fork" => {:fork, 3},
      "submit_turn" => {:submit_turn, 4},
      "steer_turn" => {:steer, 5},
      "cancel_turn" => {:cancel, 4},
      "result" => {:result, 4},
      "attachment_begin" => {:begin_attachment, 3},
      "attachment_chunk" => {:upload_attachment_chunk, 5},
      "attachment_commit" => {:commit_attachment, 3}
    }

    control_apis = %{
      "watch_progress" => {:watch_progress, 3},
      "watch_updates" => {:watch_updates, 3}
    }

    assert Map.keys(operation_apis) |> Enum.sort() == Jido.Seigyo.operations() |> Enum.sort()
    assert Map.keys(control_apis) |> Enum.sort() == Jido.Seigyo.controls() |> Enum.sort()

    Enum.each(Map.merge(operation_apis, control_apis), fn {_name, {function, arity}} ->
      assert function_exported?(Client, function, arity),
             "missing Jido.Seigyo.Client.#{function}/#{arity}"
    end)
  end
end
