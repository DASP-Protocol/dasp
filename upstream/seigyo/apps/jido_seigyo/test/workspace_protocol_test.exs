defmodule Jido.Seigyo.WorkspaceProtocolTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo

  alias Jido.Seigyo.{
    Contract,
    ExecutionTarget,
    ID,
    SandboxProfile,
    SessionConfig,
    Workspace,
    WorkspaceConfigure,
    WorkspaceConfigured,
    Workspaces
  }

  test "Workspace configuration and listing have closed path schemas" do
    workspace_id = ID.generate(:workspace)
    mutation_id = ID.generate(:mutation)

    request = %{
      "version" => 1,
      "mutation_id" => mutation_id,
      "workspace_id" => workspace_id,
      "expected_version" => nil,
      "name" => "Jido Core",
      "file_path" => "/source/jido",
      "runtime_path" => "/workspace"
    }

    assert {:ok, configure} = WorkspaceConfigure.new(request)
    assert {:ok, ^configure} = Seigyo.validate(configure)
    assert {:error, [_ | _]} = WorkspaceConfigure.new(%{request | "runtime_path" => "workspace"})

    workspace = %{
      "id" => workspace_id,
      "name" => "Jido Core",
      "file_path" => "/source/jido",
      "runtime_path" => "/workspace",
      "ownership" => "borrowed",
      "mode" => "shared",
      "status" => "ready",
      "version" => 1
    }

    assert {:ok, configured} =
             WorkspaceConfigured.new(%{
               "version" => 1,
               "mutation_id" => mutation_id,
               "disposition" => "created",
               "workspace" => workspace
             })

    assert {:ok, ^configured} = Seigyo.validate(configured)

    assert {:ok, listed} =
             Workspaces.new(%{"version" => 1, "workspaces" => [workspace]})

    assert {:ok, ^listed} = Seigyo.validate(listed)

    assert {:error, [_ | _]} =
             Workspaces.new(%{"version" => 1, "workspaces" => [workspace, workspace]})
  end

  test "Workspace and execution component schemas stay public and closed" do
    for schema <- [
          Workspace.schema(),
          ExecutionTarget.schema(),
          SandboxProfile.schema(),
          SessionConfig.sandbox_schema()
        ] do
      assert schema != nil
    end
  end

  test "path and adjacent compacted-context refinements reject each unsafe boundary" do
    assert {:error, _} = Contract.base64_chunk("", [])
    assert {:error, _} = Contract.file_path("/" <> String.duplicate("a", 4_096), [])
    assert {:error, _} = Contract.runtime_path("/" <> String.duplicate("a", 4_096), [])
    assert {:error, _} = Contract.workspace_name("", [])

    compacted = %{
      "sequence" => 10,
      "context_revision" => 2,
      "previous_context_revision" => 1,
      "source_from_sequence" => 2,
      "source_to_sequence" => 8,
      "estimated_tokens_before" => 2_000,
      "estimated_tokens_after" => 1_000
    }

    assert {:error, _} =
             Contract.context_compacted(
               %{compacted | "source_from_sequence" => 9, "source_to_sequence" => 8},
               []
             )

    assert {:error, _} =
             Contract.context_compacted(
               %{compacted | "estimated_tokens_after" => 2_001},
               []
             )

    assert {:error, _} =
             Contract.context_compacted_payload(
               %{compacted | "source_from_sequence" => 9, "source_to_sequence" => 8},
               []
             )

    assert {:error, _} =
             Contract.context_compacted_payload(
               %{compacted | "estimated_tokens_after" => 2_001},
               []
             )

    assert {:error, _} =
             Contract.context_compacted_update(
               %{"sequence" => 10, "payload" => %{"source_to_sequence" => 10}},
               []
             )
  end
end
