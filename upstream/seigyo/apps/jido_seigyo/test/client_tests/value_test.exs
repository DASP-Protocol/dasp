defmodule Jido.Seigyo.Client.ValueTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client
  alias Jido.Seigyo.ID

  test "client values are Zoi-validated structs" do
    session_id = ID.generate(:session)
    workspace_id = ID.generate(:workspace)
    command_id = ID.generate(:command)

    assert {:ok, %Client.Session{} = session} =
             Client.Session.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "workspace_id" => workspace_id,
               "protocol_version" => 1,
               "protocol_profile" => "coding"
             })

    assert session.id == session_id
    assert session.workspace_id == workspace_id

    assert {:ok, %Client.Receipt{} = receipt} =
             Client.Receipt.from_data(%{
               "version" => 1,
               "command_id" => command_id,
               "session_id" => session_id,
               "disposition" => "accepted",
               "session_revision" => 1,
               "sequence" => 1,
               "error" => nil
             })

    assert receipt.command_id == command_id
    assert {:ok, ^receipt} = Zoi.parse(Client.Receipt.schema(), receipt)

    assert {:ok,
            %Client.Receipt{
              disposition: "rejected",
              session_revision: nil,
              sequence: nil,
              error: %Jido.Seigyo.Error{code: "unavailable", field: "workspace"}
            } = rejected} =
             Client.Receipt.from_data(%{
               "version" => 1,
               "command_id" => command_id,
               "session_id" => session_id,
               "disposition" => "rejected",
               "session_revision" => nil,
               "sequence" => nil,
               "error" => %{
                 "version" => 1,
                 "code" => "unavailable",
                 "field" => "workspace"
               }
             })

    assert {:ok, ^rejected} = Zoi.parse(Client.Receipt.schema(), rejected)

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.Receipt.from_data(%{
               "version" => 1,
               "command_id" => command_id,
               "session_id" => session_id,
               "disposition" => "accepted",
               "session_revision" => nil,
               "sequence" => nil,
               "error" => %{
                 "version" => 1,
                 "code" => "unavailable",
                 "field" => "workspace"
               }
             })

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.Receipt.from_data(%{
               "version" => 1,
               "command_id" => command_id,
               "session_id" => session_id,
               "disposition" => "rejected",
               "session_revision" => nil,
               "sequence" => nil,
               "error" => %{
                 "version" => 1,
                 "code" => "unavailable",
                 "field" => "workspace",
                 "detail" => "private"
               }
             })
  end

  test "an invalid value returns a Seigyo Protocol error" do
    assert {:error, %Client.Error{kind: :protocol}} =
             Client.Session.from_data(%{
               "session_id" => "bad",
               "workspace_id" => ID.generate(:workspace)
             })

    assert {:error, %Client.Error{kind: :protocol}} = Client.Session.from_data(nil)
  end

  test "SessionForked exposes a ready child Session and closed lineage" do
    mutation_id = ID.generate(:mutation)
    session_id = ID.generate(:session)
    parent_session_id = ID.generate(:session)
    workspace_id = ID.generate(:workspace)

    data = %{
      "version" => 1,
      "mutation_id" => mutation_id,
      "session_id" => session_id,
      "root_session_id" => parent_session_id,
      "parent_session_id" => parent_session_id,
      "fork_event_cursor" => 8,
      "relation" => "fork",
      "workspace_id" => workspace_id,
      "config_revision" => 2,
      "context_revision" => 1
    }

    assert {:ok, %Client.SessionForked{} = forked} = Client.SessionForked.from_data(data)

    assert forked.session == %Client.Session{
             id: session_id,
             workspace_id: workspace_id,
             protocol_version: 1,
             protocol_profile: "coding"
           }

    assert forked.parent_session_id == parent_session_id

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("private", true)
             |> Client.SessionForked.from_data()
  end

  test "Attachment is a closed Zoi-validated value" do
    session_id = ID.generate(:session)
    attachment_id = ID.generate(:attachment)
    sha256 = String.duplicate("a", 64)

    data = %{
      "version" => 1,
      "attachment_id" => attachment_id,
      "session_id" => session_id,
      "state" => "ready",
      "name" => "requirements.md",
      "media_type" => "text/markdown",
      "size" => 3,
      "sha256" => sha256,
      "uploaded_bytes" => 3,
      "next_chunk_index" => 1,
      "error" => nil
    }

    assert {:ok, %Client.Attachment{} = attachment} = Client.Attachment.from_data(data)
    assert attachment.attachment_id == attachment_id
    assert attachment.state == "ready"
    assert {:ok, ^attachment} = Zoi.parse(Client.Attachment.schema(), attachment)

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("uploaded_bytes", 2)
             |> Client.Attachment.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("state", "rejected")
             |> Client.Attachment.from_data()
  end

  test "a Result converts closed Seigyo blocks and rejects private orchestration" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)
    workspace_id = ID.generate(:workspace)

    data = %{
      "version" => 1,
      "result_id" => ID.generate(:result),
      "session_id" => session_id,
      "command_id" => command_id,
      "completion" => "execution",
      "status" => "completed",
      "config_revision" => 2,
      "config_digest" => String.duplicate("a", 64),
      "tool_profile" => %{
        "id" => "jido_code/coding",
        "version" => "1",
        "digest" => String.duplicate("b", 64)
      },
      "context_revision" => 3,
      "model_id" => "openai:gpt-4o-mini",
      "blocks" => [
        %{"type" => "markdown", "text" => "## Done", "truncated" => false},
        %{"type" => "workspace_changes", "workspace_id" => workspace_id}
      ],
      "usage" => %{
        "measurement" => "reported",
        "input_tokens" => 10,
        "output_tokens" => 4,
        "reasoning_tokens" => 2,
        "cache_read_tokens" => 1,
        "cache_write_tokens" => 0,
        "model_calls" => 1,
        "delegated_runs" => 1
      },
      "reasoning" => %{
        "visibility" => "hidden",
        "summary" => nil,
        "truncated" => false
      },
      "error" => nil
    }

    assert {:ok,
            %Client.Result{
              blocks: [
                %Client.ResultBlock{type: "markdown", text: "## Done", truncated: false},
                %Client.ResultBlock{
                  type: "workspace_changes",
                  workspace_id: ^workspace_id
                }
              ],
              completion: "execution",
              usage: %Client.ResultUsage{
                measurement: "reported",
                model_calls: 1,
                delegated_runs: 1
              },
              reasoning: %Client.ResultReasoning{visibility: "hidden", summary: nil}
            } = result} = Client.Result.from_data(data)

    assert result.session_id == session_id
    assert result.command_id == command_id
    assert {:ok, ^result} = Zoi.parse(Client.Result.schema(), result)

    unavailable =
      data
      |> put_in(["usage", "measurement"], "unavailable")
      |> put_in(["usage", "input_tokens"], nil)
      |> put_in(["usage", "output_tokens"], nil)
      |> put_in(["usage", "reasoning_tokens"], nil)
      |> put_in(["usage", "cache_read_tokens"], nil)
      |> put_in(["usage", "cache_write_tokens"], nil)

    assert {:ok, %Client.Result{usage: %Client.ResultUsage{input_tokens: nil}}} =
             Client.Result.from_data(unavailable)

    assert {:error, [_ | _]} =
             Zoi.parse(Client.ResultUsage.schema(), %{
               result.usage
               | measurement: "unavailable"
             })

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> put_in(["blocks", Access.at(0), "workspace_id"], workspace_id)
             |> Client.Result.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("subagents", [%{"id" => "private"}])
             |> Client.Result.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("status", "failed")
             |> Client.Result.from_data()
  end

  test "turn control results are closed typed values" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)
    mutation_id = ID.generate(:mutation)

    assert {:ok,
            %Client.TurnControlled{
              mutation_id: ^mutation_id,
              target_command_id: ^command_id,
              action: "steer",
              disposition: "applied",
              sequence: 3
            } = controlled} =
             Client.TurnControlled.from_data(%{
               "version" => 1,
               "mutation_id" => mutation_id,
               "session_id" => session_id,
               "target_command_id" => command_id,
               "action" => "steer",
               "disposition" => "applied",
               "sequence" => 3
             })

    assert {:ok, ^controlled} = Zoi.parse(Client.TurnControlled.schema(), controlled)

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.TurnControlled.from_data(%{
               "version" => 1,
               "mutation_id" => mutation_id,
               "session_id" => session_id,
               "target_command_id" => command_id,
               "action" => "pause",
               "disposition" => "applied",
               "sequence" => 3
             })
  end

  test "an updates page contains Zoi-validated update structs" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)

    data = %{
      "version" => 1,
      "session_id" => session_id,
      "after_sequence" => 0,
      "updates" => [
        %{
          "version" => 1,
          "kind" => "event",
          "session_id" => session_id,
          "sequence" => 1,
          "event_type" => "command_accepted",
          "command_id" => command_id,
          "payload" => %{"kind" => "submit_text", "state" => "active"}
        }
      ],
      "next_cursor" => nil
    }

    assert {:ok,
            %Client.UpdatesPage{
              updates: [
                %Client.Update{command_kind: "submit_text", turn_state: "active", reason: nil} =
                  update
              ]
            }} =
             Client.UpdatesPage.from_data(data)

    assert update.command_id == command_id

    compacted = %{
      hd(data["updates"])
      | "sequence" => 2,
        "command_id" => nil,
        "event_type" => "context_compacted",
        "payload" => %{
          "config_revision" => 1,
          "previous_context_revision" => 0,
          "context_revision" => 1,
          "source_from_sequence" => 1,
          "source_to_sequence" => 1,
          "preserved_turns" => 1,
          "estimated_tokens_before" => 2_000,
          "estimated_tokens_after" => 700,
          "reason" => "threshold"
        }
    }

    assert {:ok,
            %Client.Update{
              event_type: "context_compacted",
              context_revision: 1,
              previous_context_revision: 0,
              reason: "threshold"
            }} = Client.Update.from_data(compacted)

    assert {:ok,
            %Client.UpdatesPage{
              updates: [%Client.Update{command_kind: nil, reason: "execution_failed"}]
            }} =
             data
             |> put_in(["updates", Access.at(0), "event_type"], "command_failed")
             |> put_in(
               ["updates", Access.at(0), "payload"],
               %{
                 "reason" => "execution_failed",
                 "result_id" => String.replace_prefix(command_id, "cmd_", "res_")
               }
             )
             |> Client.UpdatesPage.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> put_in(["updates", Access.at(0), "event_type"], "other_event")
             |> Client.UpdatesPage.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> put_in(["updates", Access.at(0), "payload"], %{})
             |> Client.UpdatesPage.from_data()

    completed = %{
      hd(data["updates"])
      | "sequence" => 2,
        "event_type" => "command_completed",
        "payload" => %{"result_id" => String.replace_prefix(command_id, "cmd_", "res_")}
    }

    coherent = %{data | "updates" => data["updates"] ++ [completed], "next_cursor" => 2}
    assert {:ok, %Client.UpdatesPage{}} = Client.UpdatesPage.from_data(coherent)

    assert {:error, %Client.Error{kind: :protocol}} =
             coherent
             |> Map.put("updates", Enum.reverse(coherent["updates"]))
             |> Client.UpdatesPage.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             coherent
             |> put_in(["updates", Access.at(1), "session_id"], ID.generate(:session))
             |> Client.UpdatesPage.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             coherent
             |> Map.put("next_cursor", 1)
             |> Client.UpdatesPage.from_data()
  end

  test "a Trace exposes the effective model as a typed field" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)

    assert {:ok,
            %Client.Trace{
              model_id: "openai:gpt-4o-mini",
              tools: [%Client.Tool{name: "repo_read", status: "ok"}]
            } = trace} =
             Client.Trace.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "command_id" => command_id,
               "model_id" => "openai:gpt-4o-mini",
               "config_revision" => 2,
               "config_digest" => String.duplicate("a", 64),
               "tool_profile" => %{
                 "id" => "jido_code/coding",
                 "version" => "1",
                 "digest" => String.duplicate("b", 64)
               },
               "status" => "completed",
               "failure_reason" => nil,
               "duration_ms" => 10,
               "model_calls" => 1,
               "input_tokens" => 2,
               "output_tokens" => 3,
               "truncated" => false,
               "tools" => [
                 %{
                   "id" => "read-1",
                   "name" => "repo_read",
                   "status" => "ok",
                   "duration_ms" => 4,
                   "truncated" => false,
                   "summary" => "Read sample.txt"
                 }
               ],
               "thinking" => "",
               "thinking_truncated" => false
             })

    assert {:ok, ^trace} = Zoi.parse(Client.Trace.schema(), trace)

    assert {:error, [_ | _]} =
             Zoi.parse(Client.Trace.schema(), %{trace | thinking: "private reasoning"})

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.Trace.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "command_id" => command_id,
               "model_id" => "openai:gpt-4o-mini",
               "config_revision" => 2,
               "config_digest" => String.duplicate("a", 64),
               "tool_profile" => %{
                 "id" => "jido_code/coding",
                 "version" => "1",
                 "digest" => String.duplicate("b", 64)
               },
               "status" => "completed",
               "failure_reason" => nil,
               "duration_ms" => 9_007_199_254_740_992,
               "model_calls" => 1,
               "input_tokens" => 2,
               "output_tokens" => 3,
               "truncated" => false,
               "tools" => [],
               "thinking" => "",
               "thinking_truncated" => false
             })
  end

  test "a View exposes typed nested values instead of raw Signal content" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)
    workspace_id = ID.generate(:workspace)
    target_id = ID.generate(:target)

    assert {:ok,
            %Client.View{
              active_command: %Client.ActiveCommand{},
              messages: [%Client.Message{}],
              recent_outcomes: [%Client.CommandOutcome{}],
              execution: %Client.ExecutionSummary{},
              workspace: %Client.WorkspaceSummary{}
            } = view} =
             Client.View.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "session_revision" => 2,
               "agent_revision" => 1,
               "event_cursor" => 2,
               "lifecycle" => "open",
               "content" => %{
                 "active_command" => %{
                   "command_id" => command_id,
                   "state" => "dispatched"
                 },
                 "last_result" => nil,
                 "last_result_command_id" => nil,
                 "messages" => [
                   %{"command_id" => command_id, "role" => "user", "text" => "Inspect"}
                 ],
                 "messages_truncated" => false,
                 "recent_outcomes" => [
                   %{
                     "command_id" => ID.generate(:command),
                     "state" => "completed",
                     "sequence" => 2
                   }
                 ],
                 "execution" => %{
                   "target_id" => target_id,
                   "sandbox_id" => nil,
                   "sandbox_profile" => nil,
                   "isolation" => "trusted_local",
                   "network" => "allowed",
                   "status" => "ready"
                 },
                 "workspace" => %{
                   "id" => workspace_id,
                   "name" => "workspace",
                   "ownership" => "borrowed",
                   "mode" => "shared",
                   "status" => "ready"
                 }
               }
             })

    assert view.active_command.command_id == command_id
    assert view.messages |> hd() |> Map.fetch!(:command_id) == command_id
    assert view.messages |> hd() |> Map.fetch!(:text) == "Inspect"
    refute view.messages_truncated
    assert view.workspace.id == workspace_id

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.View.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "session_revision" => 2,
               "agent_revision" => 1,
               "event_cursor" => 2,
               "lifecycle" => "open",
               "content" => %{
                 "active_command" => nil,
                 "last_result" => "Done",
                 "last_result_command_id" => nil,
                 "messages" => [],
                 "messages_truncated" => false,
                 "recent_outcomes" => [],
                 "workspace" => %{
                   "id" => workspace_id,
                   "name" => "workspace",
                   "ownership" => "borrowed",
                   "mode" => "shared",
                   "status" => "ready"
                 }
               }
             })
  end

  test "the execution catalog exposes typed safe targets and Sandbox profiles" do
    target_id = ID.generate(:target)

    assert {:ok,
            %Client.ExecutionCatalog{
              targets: [%Client.ExecutionTarget{} = target],
              sandbox_profiles: [%Client.SandboxProfile{} = profile]
            }} =
             Client.ExecutionCatalog.from_data(%{
               "version" => 1,
               "targets" => [
                 %{
                   "id" => target_id,
                   "name" => "Local SmolBox",
                   "status" => "ready",
                   "isolation" => ["vm"],
                   "network" => ["denied"],
                   "sandbox_profiles" => ["smolbox"],
                   "security_boundary" => "vm"
                 }
               ],
               "sandbox_profiles" => [
                 %{
                   "id" => "smolbox",
                   "name" => "SmolBox microVM",
                   "target_id" => target_id,
                   "isolation" => "vm",
                   "network" => "denied",
                   "workspace_binding" => "managed_copy",
                   "workspace_runtime_root" => "/workspace",
                   "fault_boundary" => "vm",
                   "security_boundary" => "vm"
                 }
               ]
             })

    assert target.id == target_id
    assert target.security_boundary == "vm"
    assert profile.target_id == target_id
    assert profile.fault_boundary == "vm"
    assert profile.workspace_runtime_root == "/workspace"
  end

  test "join capabilities are a Zoi-validated struct" do
    data = %{
      "version" => 1,
      "profile" => "coding",
      "principal" => "test-user",
      "operations" => ~w(open submit updates history view trace workspace_changes),
      "controls" => ~w(watch_progress watch_updates),
      "request_signal_types" => ~w(jido.client.v1.session.open jido.client.v1.command),
      "result_signal_types" => ~w(jido.client.v1.session.opened jido.client.v1.receipt),
      "push_signal_types" =>
        ~w(jido.client.v1.update jido.client.v1.progress jido.client.v1.resync.required),
      "update_event_types" => ~w(command_accepted command_completed)
    }

    assert {:ok, %Client.Capabilities{} = capabilities} =
             Client.Capabilities.from_data(data)

    assert "submit" in capabilities.operations
    assert capabilities.controls == ~w(watch_progress watch_updates)
    assert "jido.client.v1.command" in capabilities.request_signal_types

    assert capabilities.push_signal_types ==
             ~w(jido.client.v1.update jido.client.v1.progress jido.client.v1.resync.required)

    assert "command_completed" in capabilities.update_event_types

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("unexpected", true)
             |> Client.Capabilities.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("request_signal_types", ["not.a.client.signal"])
             |> Client.Capabilities.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             data
             |> Map.put("update_event_types", ["command_accepted", "command_accepted"])
             |> Client.Capabilities.from_data()
  end

  test "ResyncRequired is a Zoi-validated replay notice" do
    session_id = ID.generate(:session)

    assert {:ok, %Client.ResyncRequired{session_id: ^session_id} = notice} =
             Client.ResyncRequired.from_data(%{"version" => 1, "session_id" => session_id})

    assert {:ok, ^notice} = Zoi.parse(Client.ResyncRequired.schema(), notice)

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.ResyncRequired.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "sequence" => 9
             })
  end

  test "Progress is a typed replacement snapshot" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)

    assert {:ok,
            %Client.Progress{
              session_id: ^session_id,
              command_id: ^command_id,
              sequence: 3,
              phase: "using_tools",
              thinking: "",
              tools: [%Client.Tool{name: "repo_read", status: "running"}]
            } = progress} =
             Client.Progress.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "command_id" => command_id,
               "sequence" => 3,
               "iteration" => 1,
               "phase" => "using_tools",
               "text" => "Inspecting",
               "truncated" => false,
               "thinking" => "",
               "thinking_truncated" => false,
               "tools" => [
                 %{
                   "id" => "read-1",
                   "name" => "repo_read",
                   "status" => "running",
                   "duration_ms" => nil,
                   "truncated" => false,
                   "summary" => nil
                 }
               ],
               "tools_truncated" => false
             })

    assert {:ok, ^progress} = Zoi.parse(Client.Progress.schema(), progress)
  end

  test "history pages contain Zoi-validated entries" do
    session_id = ID.generate(:session)
    command_id = ID.generate(:command)

    assert {:ok, %Client.HistoryPage{entries: [%Client.HistoryEntry{} = entry]}} =
             Client.HistoryPage.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "entries" => [
                 %{
                   "sequence" => 1,
                   "command_id" => command_id,
                   "role" => "user",
                   "text" => "Inspect the repository",
                   "truncated" => false
                 }
               ],
               "next_cursor" => nil
             })

    assert entry.sequence == 1
    assert entry.command_id == command_id
    assert entry.role == "user"

    incoherent = %{
      "version" => 1,
      "session_id" => session_id,
      "entries" => [
        %{
          "sequence" => 1,
          "command_id" => command_id,
          "role" => "user",
          "text" => "Inspect the repository",
          "truncated" => false
        },
        %{
          "sequence" => 3,
          "command_id" => command_id,
          "role" => "assistant",
          "text" => "Done",
          "truncated" => false
        }
      ],
      "next_cursor" => 3
    }

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.HistoryPage.from_data(incoherent)

    assert {:error, %Client.Error{kind: :protocol}} =
             incoherent
             |> put_in(["entries", Access.at(1), "sequence"], 2)
             |> Map.put("next_cursor", 1)
             |> Client.HistoryPage.from_data()

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.HistoryPage.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "entries" => [
                 %{
                   "sequence" => 1,
                   "role" => "user",
                   "text" => "Inspect the repository",
                   "truncated" => false
                 }
               ],
               "next_cursor" => nil
             })
  end

  test "Workspace changes contain Zoi-validated paths" do
    session_id = ID.generate(:session)
    workspace_id = ID.generate(:workspace)

    assert {:ok,
            %Client.WorkspaceChanges{
              files: [%Client.WorkspaceChange{path: "sample.txt", status: "modified"}]
            } = changes} =
             Client.WorkspaceChanges.from_data(%{
               "version" => 1,
               "session_id" => session_id,
               "workspace_id" => workspace_id,
               "base_revision" => String.duplicate("a", 40),
               "clean" => false,
               "files" => [%{"path" => "sample.txt", "status" => "modified"}],
               "patch" => "-old\n+new\n",
               "truncated" => false
             })

    refute changes.clean

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.WorkspaceChanges.from_data(%{
               "session_id" => session_id,
               "workspace_id" => workspace_id,
               "base_revision" => nil,
               "clean" => false,
               "files" => [%{"path" => "bad\npath", "status" => "modified"}],
               "patch" => "",
               "truncated" => false
             })
  end

  test "Workspace catalog values keep host and runtime paths separate" do
    workspace_id = ID.generate(:workspace)
    mutation_id = ID.generate(:mutation)

    data = %{
      "id" => workspace_id,
      "name" => "Jido Core",
      "file_path" => "/source/jido",
      "runtime_path" => "/workspace",
      "ownership" => "borrowed",
      "mode" => "shared",
      "status" => "ready",
      "version" => 2
    }

    assert {:ok, %Client.Workspaces{workspaces: [%Client.Workspace{} = workspace]}} =
             Client.Workspaces.from_data(%{"version" => 1, "workspaces" => [data]})

    assert workspace.file_path == "/source/jido"
    assert workspace.runtime_path == "/workspace"

    assert {:ok, %Client.WorkspaceConfigured{workspace: ^workspace}} =
             Client.WorkspaceConfigured.from_data(%{
               "version" => 1,
               "mutation_id" => mutation_id,
               "disposition" => "updated",
               "workspace" => data
             })

    assert {:error, %Client.Error{kind: :protocol}} =
             Client.Workspace.from_data(%{data | "runtime_path" => "workspace"})
  end
end
