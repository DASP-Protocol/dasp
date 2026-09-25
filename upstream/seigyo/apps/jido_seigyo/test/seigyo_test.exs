defmodule Jido.SeigyoTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.{
    Attachment,
    AttachmentBegin,
    AttachmentChunk,
    AttachmentCommit,
    Command,
    ExecutionCatalog,
    Failure,
    HistoryPage,
    Progress,
    Receipt,
    ResyncRequired,
    Result,
    SessionConfiguration,
    SessionConfigure,
    SessionConfigured,
    SessionFork,
    SessionForked,
    SessionOpen,
    SessionOpened,
    Trace,
    TurnCancel,
    TurnControlled,
    TurnReceipt,
    TurnSteer,
    TurnSubmit,
    Update,
    UpdatesPage,
    View,
    WorkspaceChanges,
    WorkspaceConfigure,
    WorkspaceConfigured,
    Workspaces
  }

  alias Jido.Seigyo

  test "the coding profile publishes one canonical capability catalog" do
    assert Seigyo.version() == 1
    assert Seigyo.profile() == "coding"

    assert Seigyo.operations() ==
             ~w(open submit updates history view trace workspace_changes workspaces workspace_configure execution_catalog configuration configuration_history configure fork submit_turn steer_turn cancel_turn result attachment_begin attachment_chunk attachment_commit)

    assert Seigyo.controls() == ~w(watch_progress watch_updates)

    assert Seigyo.request_signal_types() == [
             SessionOpen.type(),
             Command.type(),
             SessionConfigure.type(),
             SessionFork.type(),
             TurnSubmit.type(),
             TurnSteer.type(),
             TurnCancel.type(),
             WorkspaceConfigure.type(),
             AttachmentBegin.type(),
             AttachmentChunk.type(),
             AttachmentCommit.type()
           ]

    assert Seigyo.result_signal_types() == [
             SessionOpened.type(),
             Receipt.type(),
             UpdatesPage.type(),
             HistoryPage.type(),
             View.type(),
             Trace.type(),
             WorkspaceChanges.type(),
             ExecutionCatalog.type(),
             SessionConfiguration.type(),
             Jido.Seigyo.SessionConfigurationsPage.type(),
             SessionConfigured.type(),
             SessionForked.type(),
             TurnReceipt.type(),
             TurnControlled.type(),
             Result.type(),
             Failure.type(),
             Workspaces.type(),
             WorkspaceConfigured.type(),
             Attachment.type()
           ]

    assert Seigyo.push_signal_types() == [
             Update.type(),
             Progress.type(),
             ResyncRequired.type()
           ]

    assert Seigyo.update_event_types() ==
             ~w(command_accepted turn_started turn_steered turn_cancel_requested command_completed command_failed command_cancelled command_uncertain session_configured context_compacted)
  end

  test "capabilities use the same catalog and add only the authenticated principal" do
    assert Seigyo.capabilities("local-user") == %{
             "version" => 1,
             "profile" => "coding",
             "principal" => "local-user",
             "operations" => Seigyo.operations(),
             "controls" => Seigyo.controls(),
             "request_signal_types" => Seigyo.request_signal_types(),
             "result_signal_types" => Seigyo.result_signal_types(),
             "push_signal_types" => Seigyo.push_signal_types(),
             "update_event_types" => Seigyo.update_event_types()
           }
  end

  test "draft Signals stay out of the advertised catalog until explicitly included" do
    alias Jido.Seigyo.{Catalog, ContextCompacted}

    assert Catalog.draft_signals() == [{:push, ContextCompacted}]
    assert Catalog.draft_signal_types(:push) == [ContextCompacted.type()]
    assert Catalog.signal_module(ContextCompacted.type()) == :error

    assert {:ok, ContextCompacted} =
             Catalog.signal_module(ContextCompacted.type(), include_drafts: true)
  end
end
