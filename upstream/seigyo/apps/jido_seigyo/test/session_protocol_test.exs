defmodule Jido.Seigyo.SessionProtocolTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo

  alias Jido.Seigyo.{
    Attachment,
    AttachmentBegin,
    AttachmentChunk,
    AttachmentCommit,
    ContextCompacted,
    Error,
    ExecutionCatalog,
    Result,
    SessionConfig,
    SessionConfiguration,
    SessionConfigurationsPage,
    SessionConfigure,
    SessionConfigured,
    SessionFork,
    SessionForked,
    TurnCancel,
    TurnControlled,
    TurnReceipt,
    TurnSteer,
    TurnSubmit
  }

  @session_id "ses_018f1a1a-7b3c-7a00-8000-000000000001"
  @source_session_id "ses_018f1a1a-7b3c-7a00-8000-000000000002"
  @root_session_id "ses_018f1a1a-7b3c-7a00-8000-000000000003"
  @command_id "cmd_018f1a1a-7b3c-7a00-8000-000000000004"
  @target_command_id "cmd_018f1a1a-7b3c-7a00-8000-000000000005"
  @workspace_id "ws_018f1a1a-7b3c-7a00-8000-000000000006"
  @target_id "tgt_018f1a1a-7b3c-7a00-8000-00000000000b"
  @sandbox_id "sbx_018f1a1a-7b3c-7a00-8000-00000000000c"
  @mutation_id "mut_018f1a1a-7b3c-7a00-8000-000000000007"
  @attachment_id "att_018f1a1a-7b3c-7a00-8000-000000000008"
  @result_id "res_018f1a1a-7b3c-7a00-8000-000000000009"
  @artifact_id "art_018f1a1a-7b3c-7a00-8000-00000000000a"
  @sha256 String.duplicate("a", 64)

  defp config do
    %{
      "version" => 1,
      "revision" => 2,
      "state" => "effective",
      "profile" => "coding",
      "model" => %{"id" => "openai:gpt-6", "reasoning_level" => "high"},
      "context" => %{
        "mode" => "managed",
        "target_tokens" => 120_000,
        "preserve_recent_turns" => 12,
        "compaction_policy" => "summarize"
      },
      "skills" => [%{"id" => "elixir-review", "version" => "2", "digest" => @sha256}],
      "plugins" => [
        %{"id" => "github", "version" => nil, "capabilities" => ~w(read pull_request)}
      ],
      "tool_profile" => %{
        "id" => "jido_code/coding",
        "version" => "1",
        "digest" => @sha256
      },
      "execution" => %{
        "workspace_id" => @workspace_id,
        "target_id" => @target_id,
        "isolation" => "trusted_local",
        "network" => "allowed",
        "sandbox" => %{"id" => @sandbox_id, "profile" => "beam_process"}
      },
      "instructions" => "Keep changes small."
    }
    |> SessionConfig.put_digest()
  end

  defp config_patch do
    %{
      "model" => %{"id" => "openai:gpt-6", "reasoning_level" => "xhigh"},
      "skills" => [],
      "plugins" => []
    }
  end

  defp usage do
    %{
      "measurement" => "reported",
      "input_tokens" => 100,
      "output_tokens" => 20,
      "reasoning_tokens" => 8,
      "cache_read_tokens" => 10,
      "cache_write_tokens" => 0,
      "model_calls" => 2,
      "delegated_runs" => 1
    }
  end

  defp result(blocks \\ [%{"type" => "markdown", "text" => "Done", "truncated" => false}]) do
    %{
      "version" => 1,
      "result_id" => @result_id,
      "session_id" => @session_id,
      "command_id" => @command_id,
      "completion" => "execution",
      "status" => "completed",
      "config_revision" => 2,
      "config_digest" => config()["digest"],
      "tool_profile" => config()["tool_profile"],
      "context_revision" => 4,
      "model_id" => "openai:gpt-6",
      "blocks" => blocks,
      "usage" => usage(),
      "reasoning" => %{"visibility" => "hidden", "summary" => nil, "truncated" => false},
      "error" => nil
    }
  end

  test "Result identifies execution completion and preserves unavailable usage" do
    assert_signal(Result, result())

    unavailable =
      result()
      |> Map.put("usage", %{
        "measurement" => "unavailable",
        "input_tokens" => nil,
        "output_tokens" => nil,
        "reasoning_tokens" => nil,
        "cache_read_tokens" => nil,
        "cache_write_tokens" => nil,
        "model_calls" => 1,
        "delegated_runs" => 0
      })

    assert_signal(Result, unavailable)

    assert {:error, [_ | _]} =
             Result.new(put_in(unavailable, ["usage", "input_tokens"], 0))

    assert {:error, [_ | _]} =
             Result.new(put_in(result(), ["usage", "input_tokens"], nil))

    assert {:error, [_ | _]} = Result.new(Map.put(result(), "completion", "verification"))
  end

  defp attachment(state \\ "ready") do
    error = if state == "rejected", do: Error.to_map(Error.new("unavailable")), else: nil
    uploaded = if state == "ready", do: 3, else: 0

    %{
      "version" => 1,
      "attachment_id" => @attachment_id,
      "session_id" => @session_id,
      "state" => state,
      "name" => "notes.txt",
      "media_type" => "text/plain",
      "size" => 3,
      "sha256" => @sha256,
      "uploaded_bytes" => uploaded,
      "next_chunk_index" => if(state == "ready", do: 1, else: 0),
      "error" => error
    }
  end

  defp assert_signal(module, data) do
    assert {:ok, signal} = module.new(data)
    assert {:ok, ^signal} = Seigyo.validate(signal)
    assert {:error, [_ | _]} = module.new(Map.put(data, "extra", true))
    signal
  end

  test "only unimplemented standalone push types stay outside capabilities" do
    assert Seigyo.draft_operations() == []
    assert Seigyo.draft_request_signal_types() == []
    assert Seigyo.draft_result_signal_types() == []

    assert Seigyo.draft_push_signal_types() == [ContextCompacted.type()]

    capabilities = Seigyo.capabilities("local-user")
    assert Enum.all?(Seigyo.draft_operations(), &(&1 not in capabilities["operations"]))

    assert Enum.all?(
             Seigyo.draft_request_signal_types(),
             &(&1 not in capabilities["request_signal_types"])
           )

    assert "steer_turn" in capabilities["operations"]
    assert "cancel_turn" in capabilities["operations"]
    assert TurnSteer.type() in capabilities["request_signal_types"]
    assert TurnCancel.type() in capabilities["request_signal_types"]
    assert TurnControlled.type() in capabilities["result_signal_types"]
    assert "fork" in capabilities["operations"]
    assert SessionFork.type() in capabilities["request_signal_types"]
    assert SessionForked.type() in capabilities["result_signal_types"]
    assert "execution_catalog" in capabilities["operations"]
    assert ExecutionCatalog.type() in capabilities["result_signal_types"]
    assert "attachment_begin" in capabilities["operations"]
    assert "attachment_chunk" in capabilities["operations"]
    assert "attachment_commit" in capabilities["operations"]
    assert AttachmentBegin.type() in capabilities["request_signal_types"]
    assert AttachmentChunk.type() in capabilities["request_signal_types"]
    assert AttachmentCommit.type() in capabilities["request_signal_types"]
    assert Attachment.type() in capabilities["result_signal_types"]
  end

  test "execution placement publishes safe targets and honest Sandbox boundaries" do
    assert_signal(ExecutionCatalog, %{
      "version" => 1,
      "targets" => [
        %{
          "id" => @target_id,
          "name" => "Local BEAM",
          "status" => "ready",
          "isolation" => ["trusted_local"],
          "network" => ["allowed"],
          "sandbox_profiles" => ["beam_process"],
          "security_boundary" => "none"
        }
      ],
      "sandbox_profiles" => [
        %{
          "id" => "beam_process",
          "name" => "BEAM process",
          "target_id" => @target_id,
          "isolation" => "trusted_local",
          "network" => "allowed",
          "workspace_binding" => "borrowed",
          "workspace_runtime_root" => nil,
          "fault_boundary" => "beam_process",
          "security_boundary" => "none"
        }
      ]
    })

    assert Jido.Seigyo.ID.valid?(@target_id, :target)
    assert Jido.Seigyo.ID.valid?(@sandbox_id, :sandbox)
  end

  test "execution placement represents an offline SmolBox VM boundary" do
    assert_signal(ExecutionCatalog, %{
      "version" => 1,
      "targets" => [
        %{
          "id" => @target_id,
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
          "target_id" => @target_id,
          "isolation" => "vm",
          "network" => "denied",
          "workspace_binding" => "managed_copy",
          "workspace_runtime_root" => "/workspace",
          "fault_boundary" => "vm",
          "security_boundary" => "vm"
        }
      ]
    })

    smolbox_config =
      config()
      |> put_in(["execution", "isolation"], "vm")
      |> put_in(["execution", "network"], "denied")
      |> put_in(["execution", "sandbox", "profile"], "smolbox")
      |> SessionConfig.put_digest()

    assert {:ok, _config} = Zoi.parse(SessionConfig.schema(), smolbox_config)
  end

  test "Session configuration has closed effective and patch schemas" do
    assert {:ok, _} = Zoi.parse(SessionConfig.schema(), config())
    assert {:ok, _} = Zoi.parse(SessionConfig.model_schema(), config()["model"])
    assert {:ok, _} = Zoi.parse(SessionConfig.context_schema(), config()["context"])
    assert {:ok, _} = Zoi.parse(SessionConfig.skill_schema(), hd(config()["skills"]))
    assert {:ok, _} = Zoi.parse(SessionConfig.plugin_schema(), hd(config()["plugins"]))
    assert {:ok, _} = Zoi.parse(SessionConfig.tool_profile_schema(), config()["tool_profile"])
    assert {:ok, _} = Zoi.parse(SessionConfig.execution_schema(), config()["execution"])
    assert {:ok, _} = Zoi.parse(SessionConfig.patch_schema(), config_patch())
    assert {:error, [_ | _]} = Zoi.parse(SessionConfig.patch_schema(), %{})
    assert {:error, [_ | _]} = Zoi.parse(SessionConfig.schema(), Map.put(config(), "extra", true))

    assert {:error, [_ | _]} =
             Zoi.parse(SessionConfig.schema(), Map.put(config(), "digest", @sha256))

    assert {:error, [_ | _]} =
             Zoi.parse(SessionConfig.patch_schema(), %{"tool_profile" => config()["tool_profile"]})

    request = %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "expected_revision" => 2,
      "apply" => "next_command",
      "patch" => config_patch()
    }

    assert_signal(SessionConfigure, request)

    assert_signal(SessionConfiguration, %{
      "version" => 1,
      "session_id" => @session_id,
      "effective" => config(),
      "pending" => %{config() | "revision" => 3, "state" => "pending"}
    })

    assert {:error, [_ | _]} =
             SessionConfiguration.new(%{
               "version" => 1,
               "session_id" => @session_id,
               "effective" => %{config() | "state" => "pending"},
               "pending" => nil
             })

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configuration(
               %{
                 "effective" => config(),
                 "pending" => %{config() | "revision" => 3, "state" => "effective"}
               },
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configuration(
               %{
                 "effective" => config(),
                 "pending" => %{config() | "revision" => 2, "state" => "pending"}
               },
               []
             )

    assert_signal(SessionConfigured, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "sequence" => 21,
      "disposition" => "pending",
      "previous_revision" => 2,
      "effective_from" => "next_command",
      "config" => %{config() | "revision" => 3, "state" => "pending"}
    })

    assert {:error, [_ | _]} =
             SessionConfigured.new(%{
               "version" => 1,
               "mutation_id" => @mutation_id,
               "session_id" => @session_id,
               "sequence" => 21,
               "disposition" => "applied",
               "previous_revision" => 2,
               "effective_from" => "next_command",
               "config" => %{config() | "revision" => 3, "state" => "pending"}
             })

    configured = %{
      "previous_revision" => 2,
      "effective_from" => "current",
      "disposition" => "applied",
      "config" => %{config() | "revision" => 3, "state" => "effective"}
    }

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configured(
               put_in(configured, ["config", "revision"], 4),
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configured(
               %{configured | "effective_from" => "next_command"},
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configured(
               %{
                 configured
                 | "effective_from" => "current",
                   "config" => %{configured["config"] | "state" => "pending"}
               },
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_configured(
               %{configured | "disposition" => "pending"},
               []
             )
  end

  test "configuration history pages bind ordered revisions to the request cursor" do
    revision_three = %{config() | "revision" => 3, "state" => "pending"}

    assert_signal(SessionConfigurationsPage, %{
      "version" => 1,
      "session_id" => @session_id,
      "oldest_revision" => 2,
      "after_revision" => nil,
      "configurations" => [config(), revision_three],
      "next_cursor" => nil
    })

    assert {:error, [_ | _]} =
             SessionConfigurationsPage.new(%{
               "version" => 1,
               "session_id" => @session_id,
               "oldest_revision" => 2,
               "after_revision" => 2,
               "configurations" => [config()],
               "next_cursor" => nil
             })
  end

  test "forks and side chats have explicit lineage and Workspace policy" do
    request = %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "source_session_id" => @source_session_id,
      "session_id" => @session_id,
      "at_event_cursor" => 20,
      "relation" => "side_chat",
      "config_policy" => "override",
      "workspace_policy" => "shared_read_only",
      "config_patch" => config_patch()
    }

    assert_signal(SessionFork, request)

    assert {:error, [_ | _]} =
             SessionFork.new(%{request | "config_policy" => "inherit"})

    assert_signal(SessionForked, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "root_session_id" => @root_session_id,
      "parent_session_id" => @source_session_id,
      "fork_event_cursor" => 20,
      "relation" => "side_chat",
      "workspace_id" => @workspace_id,
      "config_revision" => 1,
      "context_revision" => 1
    })
  end

  test "queued turns, steering, and cancellation are distinct intents" do
    assert_signal(TurnSubmit, %{
      "version" => 1,
      "command_id" => @command_id,
      "session_id" => @session_id,
      "text" => "Implement the change",
      "attachment_ids" => [@attachment_id],
      "delivery" => "enqueue",
      "expected_config_revision" => 2
    })

    assert_signal(TurnSteer, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "target_command_id" => @target_command_id,
      "text" => "Keep the public API unchanged",
      "attachment_ids" => []
    })

    assert_signal(TurnCancel, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "target_command_id" => @target_command_id,
      "reason" => "The requirement changed"
    })

    assert_signal(TurnReceipt, %{
      "version" => 1,
      "command_id" => @command_id,
      "session_id" => @session_id,
      "disposition" => "accepted",
      "state" => "queued",
      "session_revision" => 3,
      "sequence" => 21,
      "error" => nil
    })

    assert_signal(TurnReceipt, %{
      "version" => 1,
      "command_id" => @command_id,
      "session_id" => @session_id,
      "disposition" => "duplicate",
      "state" => "queued",
      "session_revision" => 3,
      "sequence" => 21,
      "error" => nil
    })

    assert_signal(TurnReceipt, %{
      "version" => 1,
      "command_id" => @command_id,
      "session_id" => @session_id,
      "disposition" => "rejected",
      "state" => nil,
      "session_revision" => nil,
      "sequence" => nil,
      "error" => Error.to_map(Error.new("conflict", "command_id"))
    })

    assert_signal(TurnControlled, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "target_command_id" => @target_command_id,
      "action" => "steer",
      "disposition" => "applied",
      "sequence" => 22
    })

    assert_signal(TurnControlled, %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "target_command_id" => @target_command_id,
      "action" => "steer",
      "disposition" => "duplicate",
      "sequence" => 22
    })

    assert {:error, [_ | _]} =
             TurnReceipt.new(%{
               "version" => 1,
               "command_id" => @command_id,
               "session_id" => @session_id,
               "disposition" => "rejected",
               "state" => "queued",
               "session_revision" => nil,
               "sequence" => nil,
               "error" => Error.to_map(Error.new("conflict", "command_id"))
             })

    assert {:error, [_ | _]} =
             TurnControlled.new(%{
               "version" => 1,
               "mutation_id" => @mutation_id,
               "session_id" => @session_id,
               "target_command_id" => @target_command_id,
               "action" => "cancel",
               "disposition" => "applied",
               "sequence" => nil
             })
  end

  test "Results normalize content and hide internal orchestration" do
    blocks = [
      %{"type" => "markdown", "text" => "Done", "truncated" => false},
      %{"type" => "attachment", "attachment_id" => @attachment_id},
      %{
        "type" => "artifact",
        "artifact_id" => @artifact_id,
        "name" => "report.md",
        "media_type" => "text/markdown"
      },
      %{"type" => "workspace_changes", "workspace_id" => @workspace_id},
      %{"type" => "citation", "uri" => "https://example.test/source", "title" => "Source"}
    ]

    for block <- blocks do
      assert {:ok, ^block} = Zoi.parse(Result.block_schema(), block)
    end

    assert {:ok, _} = Zoi.parse(Result.usage_schema(), usage())

    assert {:ok, _} =
             Zoi.parse(Result.reasoning_schema(), %{
               "visibility" => "summary",
               "summary" => "Compared both implementations",
               "truncated" => false
             })

    assert_signal(Result, result(blocks))

    oversized_blocks =
      List.duplicate(
        %{
          "type" => "markdown",
          "text" => String.duplicate("x", Seigyo.Contract.result_text_limit()),
          "truncated" => false
        },
        9
      )

    assert {:error, [_ | _]} = Result.new(result(oversized_blocks))

    assert {:error, [_ | _]} =
             Result.new(%{
               result()
               | "status" => "failed",
                 "error" => nil
             })

    failed = %{
      result([])
      | "status" => "failed",
        "error" => Error.to_map(Error.new("unavailable"))
    }

    assert_signal(Result, failed)
  end

  test "Attachments use bounded verified chunks and explicit states" do
    assert_signal(AttachmentBegin, %{
      "version" => 1,
      "attachment_id" => @attachment_id,
      "session_id" => @session_id,
      "name" => "notes.txt",
      "media_type" => "text/plain",
      "size" => 3,
      "sha256" => @sha256,
      "purpose" => "context"
    })

    assert_signal(AttachmentChunk, %{
      "version" => 1,
      "attachment_id" => @attachment_id,
      "index" => 0,
      "data" => Base.encode64("abc")
    })

    assert_signal(AttachmentCommit, %{
      "version" => 1,
      "attachment_id" => @attachment_id
    })

    assert_signal(Attachment, attachment())
    assert_signal(Attachment, attachment("uploading"))
    assert_signal(Attachment, attachment("rejected"))

    assert {:error, [_ | _]} =
             Attachment.new(%{attachment() | "uploaded_bytes" => 2})

    assert {:error, [_ | _]} =
             Attachment.new(%{attachment("uploading") | "uploaded_bytes" => 4})
  end

  test "context compaction is a versioned durable fact" do
    compacted = %{
      "version" => 1,
      "session_id" => @session_id,
      "sequence" => 21,
      "config_revision" => 2,
      "previous_context_revision" => 3,
      "context_revision" => 4,
      "source_from_sequence" => 1,
      "source_to_sequence" => 20,
      "preserved_turns" => 12,
      "estimated_tokens_before" => 140_000,
      "estimated_tokens_after" => 80_000,
      "reason" => "threshold"
    }

    assert_signal(ContextCompacted, compacted)

    assert {:error, [_ | _]} =
             ContextCompacted.new(%{compacted | "context_revision" => 6})

    assert {:error, [_ | _]} =
             ContextCompacted.new(%{
               compacted
               | "source_from_sequence" => 20,
                 "source_to_sequence" => 19
             })

    assert {:error, [_ | _]} =
             ContextCompacted.new(%{compacted | "source_to_sequence" => 21})

    assert {:error, [_ | _]} =
             ContextCompacted.new(%{compacted | "estimated_tokens_after" => 150_000})
  end

  test "new scalar refinements enforce exact safe boundaries" do
    for kind <- ~w(mutation attachment result artifact)a do
      id = Seigyo.ID.generate(kind)
      assert Seigyo.ID.valid?(id, kind)
    end

    assert :ok =
             Seigyo.Contract.session_instructions(
               String.duplicate("x", Seigyo.Contract.session_instructions_limit()),
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.session_instructions(
               String.duplicate("x", Seigyo.Contract.session_instructions_limit() + 1),
               []
             )

    assert :ok =
             Seigyo.Contract.result_text(
               String.duplicate("x", Seigyo.Contract.result_text_limit()),
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.result_text(
               String.duplicate("x", Seigyo.Contract.result_text_limit() + 1),
               []
             )

    assert Seigyo.Contract.attachment_chunk_limit() == 65_536
    assert Seigyo.Contract.attachment_size_limit() == 104_857_600
    assert :ok = Seigyo.Contract.attachment_size(104_857_600, [])
    assert {:error, %Zoi.Error{}} = Seigyo.Contract.attachment_size(104_857_601, [])
    assert :ok = Seigyo.Contract.reference("skill/example", [])
    assert {:error, %Zoi.Error{}} = Seigyo.Contract.reference("bad\nreference", [])
    assert :ok = Seigyo.Contract.sha256(@sha256, [])
    assert {:error, %Zoi.Error{}} = Seigyo.Contract.sha256("bad", [])
    assert :ok = Seigyo.Contract.media_type("application/json", [])
    assert {:error, %Zoi.Error{}} = Seigyo.Contract.media_type("not a type", [])
    assert :ok = Seigyo.Contract.base64_chunk(Base.encode64("abc"), [])
    assert {:error, %Zoi.Error{}} = Seigyo.Contract.base64_chunk("not base64", [])

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.base64_chunk(
               Base.encode64(String.duplicate("x", 65_537)),
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.reasoning(
               %{"visibility" => "hidden", "summary" => "must not be visible"},
               []
             )

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.result(%{"status" => "completed", "error" => %{}}, [])

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.result(%{"status" => "cancelled", "error" => %{}}, [])

    assert {:error, %Zoi.Error{}} =
             Seigyo.Contract.attachment(
               %{"state" => "rejected", "error" => nil, "uploaded_bytes" => 0, "size" => 3},
               []
             )
  end
end
