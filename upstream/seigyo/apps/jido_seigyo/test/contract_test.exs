defmodule Jido.Seigyo.ContractTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo
  alias Jido.Seigyo.Contract

  alias Jido.Seigyo.{
    Command,
    Error,
    ExecutionCatalog,
    Failure,
    HistoryEntry,
    HistoryPage,
    ID,
    Progress,
    Receipt,
    ResyncRequired,
    SessionOpen,
    SessionOpened,
    Tool,
    Trace,
    Update,
    UpdatesPage,
    Value,
    View,
    WorkspaceChange,
    WorkspaceChanges
  }

  @session_id "ses_018f1a1a-7b3c-7a00-8000-000000000001"
  @other_session_id "ses_018f1a1a-7b3c-7a00-8000-000000000004"
  @command_id "cmd_018f1a1a-7b3c-7a00-8000-000000000002"
  @workspace_id "ws_018f1a1a-7b3c-7a00-8000-000000000003"
  @target_id "tgt_018f1a1a-7b3c-7a00-8000-000000000005"
  @unsafe_integer 9_007_199_254_740_992

  test "client Signal type names put the protocol version before the message" do
    schema = Zoi.string() |> Zoi.refine({Contract, :signal_type, []})

    assert {:ok, "jido.client.v1.workspace.changes"} =
             Zoi.parse(schema, "jido.client.v1.workspace.changes")

    for value <- [
          "jido.server.v1.view",
          "jido.client.v1.View",
          "jido.client.v0.view",
          "jido.client.workspace.changes.v1",
          "jido.client.v1",
          String.duplicate("x", 129)
        ] do
      assert {:error, [_ | _]} = Zoi.parse(schema, value)
    end
  end

  test "protocol integers stay exact in JSON clients" do
    assert {"too_large", "session_revision"} =
             error_code(check(Receipt, %{receipt() | "session_revision" => @unsafe_integer}))

    assert {"too_large", "sequence"} =
             error_code(check(Update, %{update() | "sequence" => @unsafe_integer}))

    assert {"too_large", "event_cursor"} =
             error_code(check(View, %{view() | "event_cursor" => @unsafe_integer}))

    assert {"too_large", "iteration"} =
             error_code(check(Progress, %{progress() | "iteration" => @unsafe_integer}))

    assert {"too_large", "next_cursor"} =
             error_code(check(UpdatesPage, %{updates_page() | "next_cursor" => @unsafe_integer}))
  end

  defp command(kind \\ "submit_text", input \\ %{"text" => "hello"}) do
    %{
      "version" => 1,
      "id" => @command_id,
      "session_id" => @session_id,
      "kind" => kind,
      "input" => input
    }
  end

  defp receipt(disposition \\ "accepted") do
    %{
      "version" => 1,
      "command_id" => @command_id,
      "session_id" => @session_id,
      "disposition" => disposition,
      "session_revision" => 3,
      "sequence" => 7,
      "error" => nil
    }
  end

  defp rejected_receipt do
    %{
      receipt("rejected")
      | "session_revision" => nil,
        "sequence" => nil,
        "error" => Error.to_map(Error.new("conflict", "id"))
    }
  end

  defp view do
    %{
      "version" => 1,
      "session_id" => @session_id,
      "session_revision" => 3,
      "agent_revision" => nil,
      "event_cursor" => 7,
      "lifecycle" => "open",
      "content" => %{
        "active_command" => nil,
        "last_result" => "hello",
        "last_result_command_id" => @command_id,
        "messages" => [
          %{"command_id" => @command_id, "role" => "assistant", "text" => "hello"}
        ],
        "messages_truncated" => false,
        "recent_outcomes" => [
          %{"command_id" => @command_id, "state" => "completed", "sequence" => 7}
        ],
        "execution" => %{
          "target_id" => @target_id,
          "sandbox_id" => nil,
          "sandbox_profile" => nil,
          "isolation" => "trusted_local",
          "network" => "allowed",
          "status" => "ready"
        },
        "workspace" => %{
          "id" => @workspace_id,
          "name" => "workspace",
          "ownership" => "borrowed",
          "mode" => "shared",
          "status" => "ready"
        }
      }
    }
  end

  defp update(kind \\ "event") do
    %{
      "version" => 1,
      "session_id" => @session_id,
      "kind" => kind,
      "sequence" => 8,
      "event_type" => "command_accepted",
      "command_id" => @command_id,
      "payload" => %{"kind" => "submit_text", "state" => "active"}
    }
  end

  defp gap do
    %{
      update("gap")
      | "sequence" => 20,
        "event_type" => nil,
        "command_id" => nil,
        "payload" => nil
    }
  end

  defp updates_page do
    %{
      "version" => 1,
      "session_id" => @session_id,
      "after_sequence" => 7,
      "updates" => [
        %{update() | "payload" => %{"kind" => "submit_text", "state" => "active"}}
      ],
      "next_cursor" => 8
    }
  end

  defp history_page do
    %{
      "version" => 1,
      "session_id" => @session_id,
      "entries" => [
        %{
          "sequence" => 1,
          "command_id" => @command_id,
          "role" => "user",
          "text" => "Inspect",
          "truncated" => false
        },
        %{
          "sequence" => 2,
          "command_id" => @command_id,
          "role" => "assistant",
          "text" => "Done",
          "truncated" => false
        }
      ],
      "next_cursor" => 2
    }
  end

  defp progress do
    %{
      "version" => 1,
      "session_id" => @session_id,
      "command_id" => @command_id,
      "sequence" => 2,
      "iteration" => 1,
      "phase" => "writing",
      "text" => "Partial answer",
      "truncated" => false,
      "thinking" => "Checked the request",
      "thinking_truncated" => false,
      "tools" => [
        %{
          "id" => "tool_1",
          "name" => "repo_read",
          "status" => "running",
          "duration_ms" => nil,
          "truncated" => false,
          "summary" => nil
        }
      ],
      "tools_truncated" => false
    }
  end

  defp error_code({:error, %Error{code: code, field: field}}), do: {code, field}

  defp check(module, data) do
    case module.validate_data(data) do
      {:ok, _data} -> :ok
      {:error, errors} -> {:error, Error.from_zoi(errors)}
    end
  end

  test "IDs use typed Jido Signal UUIDv7 values" do
    assert Seigyo.version() == 1
    session_ids = for _ <- 1..20, do: ID.generate(:session)
    assert length(Enum.uniq(session_ids)) == 20
    assert Enum.all?(session_ids, &ID.valid?(&1, :session))
    assert Enum.all?(session_ids, fn "ses_" <> uuid -> Jido.Signal.ID.valid?(uuid) end)

    command_id = ID.generate(:command)
    assert ID.valid?(command_id, :command)
    workspace_id = ID.generate(:workspace)
    assert ID.valid?(workspace_id, :workspace)
    assert String.starts_with?(workspace_id, "ws_")
    refute ID.valid?(command_id, :session)
    refute ID.valid?(@session_id, :command)
    refute ID.valid?(String.upcase(@session_id), :session)
    refute ID.valid?("ses_" <> String.duplicate("a", 35), :session)
    refute ID.valid?("ses_" <> String.duplicate("g", 36), :session)
    refute ID.valid?(123, :session)
    refute ID.valid?(@session_id, :unknown)
  end

  test "client Signal types use the jido namespace" do
    assert SessionOpen.type() == "jido.client.v1.session.open"
    assert SessionOpened.type() == "jido.client.v1.session.opened"
    assert Command.type() == "jido.client.v1.command"
    assert Receipt.type() == "jido.client.v1.receipt"
    assert View.type() == "jido.client.v1.view"
    assert Update.type() == "jido.client.v1.update"
    assert Progress.type() == "jido.client.v1.progress"
    assert ResyncRequired.type() == "jido.client.v1.resync.required"
    assert Trace.type() == "jido.client.v1.trace"
    assert HistoryPage.type() == "jido.client.v1.history.page"
    assert WorkspaceChanges.type() == "jido.client.v1.workspace.changes"
    assert ExecutionCatalog.type() == "jido.client.v1.execution.catalog"
  end

  test "reusable schemas are closed protocol contracts" do
    history_entry = %{
      "sequence" => 1,
      "command_id" => @command_id,
      "role" => "user",
      "text" => "Inspect",
      "truncated" => false
    }

    tool = %{
      "id" => "tool_1",
      "name" => "repo_read",
      "status" => "running",
      "duration_ms" => nil,
      "truncated" => false,
      "summary" => nil
    }

    workspace_change = %{"path" => "lib/example.ex", "status" => "modified"}

    for {schema, value} <- [
          {HistoryEntry.schema(), history_entry},
          {Tool.schema(), tool},
          {WorkspaceChange.schema(), workspace_change},
          {View.content_schema(), view()["content"]},
          {Update.remote_schema(), update()}
        ] do
      assert {:ok, ^value} = Zoi.parse(schema, value)
      assert {:error, [_ | _]} = Zoi.parse(schema, Map.put(value, "extra", true))
    end
  end

  test "published byte limits accept the boundary and reject one byte more" do
    progress_limit = Contract.progress_text_limit()
    history_limit = Contract.history_text_limit()
    patch_limit = Contract.workspace_patch_limit()

    assert Contract.max_json_integer() == 9_007_199_254_740_991
    assert Contract.websocket_frame_bytes_limit() == 524_288
    assert Contract.signal_json_bytes_limit() == 512_000
    assert Contract.updates_page_json_bytes_limit() == 262_144
    assert Contract.request_ref_bytes_limit() == 128
    assert Contract.page_items_limit() == 100

    assert :ok = Contract.request_ref(String.duplicate("x", 128), [])

    assert {:error, %Zoi.Error{}} =
             Contract.request_ref(String.duplicate("x", 129), [])

    assert {:error, %Zoi.Error{}} = Contract.request_ref("bad\nref", [])

    for {validator, limit} <- [
          {:progress_text, progress_limit},
          {:history_text, history_limit},
          {:workspace_patch, patch_limit}
        ] do
      assert :ok = apply(Contract, validator, [String.duplicate("x", limit), []])

      assert {:error, %Zoi.Error{}} =
               apply(Contract, validator, [String.duplicate("x", limit + 1), []])
    end

    assert :ok = Contract.workspace_path(String.duplicate("x", 4_096), [])

    assert {:error, %Zoi.Error{}} =
             Contract.workspace_path(String.duplicate("x", 4_097), [])
  end

  test "portable refinement returns a protocol error for non-portable values" do
    assert :ok = Contract.portable(%{"items" => [nil, true, 1, "text"]}, [])
    assert {:error, %Zoi.Error{}} = Contract.portable(%{"pid" => self()}, [])
  end

  test "configuration history rejects every cursor and revision inconsistency" do
    page = %{
      "oldest_revision" => 2,
      "after_revision" => nil,
      "configurations" => [%{"revision" => 2}, %{"revision" => 3}],
      "next_cursor" => nil
    }

    assert :ok = Contract.configuration_history_page(page, [])

    for invalid <- [
          %{page | "configurations" => [%{"revision" => 3}, %{"revision" => 2}]},
          %{page | "configurations" => [%{"revision" => 2}, %{"revision" => 2}]},
          %{page | "configurations" => [%{"revision" => 2}, %{"revision" => 4}]},
          %{page | "configurations" => [], "next_cursor" => 2}
        ] do
      assert {:error, %Zoi.Error{}} = Contract.configuration_history_page(invalid, [])
    end
  end

  test "mixed Result usage accepts a partial provider measurement" do
    usage = %{
      "measurement" => "mixed",
      "input_tokens" => 10,
      "output_tokens" => nil,
      "reasoning_tokens" => nil,
      "cache_read_tokens" => nil,
      "cache_write_tokens" => nil
    }

    assert :ok = Contract.result_usage(usage, [])
  end

  test "history and Workspace changes use bounded client data" do
    assert {:ok, history} =
             HistoryPage.new(%{
               "version" => 1,
               "session_id" => @session_id,
               "entries" => [
                 %{
                   "sequence" => 1,
                   "command_id" => @command_id,
                   "role" => "user",
                   "text" => "Change the greeting",
                   "truncated" => false
                 },
                 %{
                   "sequence" => 2,
                   "command_id" => @command_id,
                   "role" => "assistant",
                   "text" => "Done",
                   "truncated" => false
                 }
               ],
               "next_cursor" => nil
             })

    assert {:ok, ^history} = Seigyo.validate(history)

    assert {:ok, changes} =
             WorkspaceChanges.new(%{
               "version" => 1,
               "session_id" => @session_id,
               "workspace_id" => "ws_018f1a1a-7b3c-7a00-8000-000000000003",
               "base_revision" => String.duplicate("a", 40),
               "clean" => false,
               "files" => [%{"path" => "lib/example.ex", "status" => "modified"}],
               "patch" => "-old\n+new\n",
               "truncated" => false
             })

    assert {:ok, ^changes} = Seigyo.validate(changes)

    assert {:error, [_ | _]} =
             WorkspaceChanges.new(%{
               changes.data
               | "files" => [%{"path" => "bad\npath", "status" => "modified"}]
             })
  end

  test "a Trace identifies the effective model without provider configuration" do
    data = %{
      "version" => 1,
      "session_id" => @session_id,
      "command_id" => @command_id,
      "model_id" => "openai:gpt-4o-mini",
      "config_revision" => 0,
      "config_digest" => String.duplicate("a", 64),
      "tool_profile" => %{
        "id" => "jido_code/coding",
        "version" => "1",
        "digest" => String.duplicate("b", 64)
      },
      "status" => "completed",
      "failure_reason" => nil,
      "duration_ms" => 12,
      "model_calls" => 1,
      "input_tokens" => 3,
      "output_tokens" => 2,
      "truncated" => false,
      "tools" => [],
      "thinking" => "",
      "thinking_truncated" => false
    }

    assert {:ok, trace} = Trace.new(data)
    assert {:ok, ^trace} = Seigyo.validate(trace)
    assert trace.data["model_id"] == "openai:gpt-4o-mini"
    assert {:ok, _legacy_trace} = Trace.new(%{data | "model_id" => nil})

    assert {:error, [_ | _]} =
             Trace.new(%{data | "model_id" => String.duplicate("x", 257)})
  end

  test "Session open Signals carry one validated Workspace choice" do
    session_id = ID.generate(:session)
    workspace_id = ID.generate(:workspace)

    assert {:ok, request} =
             SessionOpen.new(%{
               "version" => 1,
               "session_id" => session_id,
               "workspace_id" => workspace_id
             })

    assert {:ok, ^request} = Seigyo.validate(request)

    assert {:ok, result} =
             SessionOpened.new(%{
               "version" => 1,
               "session_id" => session_id,
               "workspace_id" => workspace_id,
               "protocol_version" => 1,
               "protocol_profile" => "coding"
             })

    assert {:ok, ^result} = Seigyo.validate(result)

    assert {:error, %Error{code: "invalid_id", field: "workspace_id"}} =
             Seigyo.validate(%{request | data: %{request.data | "workspace_id" => "bad"}})
  end

  test "the supported command uses one validated data contract" do
    map = command()
    assert :ok = check(Command, map)
    assert {:ok, signal} = Command.new(map)
    assert signal.data == map

    assert error_code(check(Command, nil)) == {"invalid_field", "shape"}

    assert error_code(check(Command, Map.put(command(), "extra", 1))) ==
             {"invalid_field", "shape"}

    assert error_code(check(Command, %{command() | "version" => 2})) ==
             {"unsupported_version", "version"}

    assert error_code(check(Command, %{command() | "id" => @session_id})) ==
             {"invalid_id", "id"}

    assert error_code(check(Command, %{command() | "session_id" => @command_id})) ==
             {"invalid_id", "session_id"}

    assert error_code(check(Command, %{command() | "kind" => "run_shell"})) ==
             {"invalid_field", "kind"}
  end

  test "command input is bounded and matches its kind" do
    assert :ok =
             check(
               Command,
               command("submit_text", %{"text" => "hello", "model" => "lmstudio:gemma"})
             )

    for input <- [
          nil,
          %{},
          %{"text" => 3},
          %{"text" => " "},
          %{"text" => <<255>>},
          %{"text" => "ok", "other" => true},
          %{"text" => "ok", "model" => " "},
          %{"text" => "ok", "model" => "ollama:bad\nmodel"}
        ] do
      assert error_code(check(Command, command("submit_text", input))) ==
               {"invalid_field", "input"}
    end

    assert error_code(
             check(Command, command("submit_text", %{"text" => String.duplicate("x", 8_193)}))
           ) ==
             {"too_large", "input"}

    for kind <- ~w(cancel close) do
      assert error_code(check(Command, command(kind, %{"text" => "ignore"}))) ==
               {"invalid_field", "kind"}
    end

    assert {:error, [_ | _]} = Command.new(%{command() | "kind" => "run_shell"})
    assert {:error, [_ | _]} = Command.new(%{command() | "id" => "bad"})
  end

  test "accepted and duplicate receipts keep the original sequence" do
    for disposition <- ~w(accepted duplicate) do
      map = receipt(disposition)
      assert :ok = check(Receipt, map)
      assert {:ok, signal} = Receipt.new(map)
      assert signal.data == map
    end

    assert :ok = check(Receipt, rejected_receipt())
    assert {:ok, signal} = Receipt.new(rejected_receipt())
    assert signal.data == rejected_receipt()
  end

  test "receipt position and error presence follow the disposition" do
    rejected = rejected_receipt()

    assert error_code(check(Receipt, %{rejected | "session_revision" => 2})) ==
             {"invalid_field", "session_revision"}

    assert error_code(check(Receipt, %{rejected | "sequence" => 4})) ==
             {"invalid_field", "sequence"}

    assert error_code(check(Receipt, %{rejected | "error" => nil})) ==
             {"invalid_field", "error"}

    assert error_code(check(Receipt, %{receipt() | "session_revision" => -1})) ==
             {"invalid_field", "session_revision"}

    assert error_code(check(Receipt, %{receipt() | "sequence" => 0})) ==
             {"invalid_field", "sequence"}

    assert error_code(check(Receipt, %{receipt() | "error" => Error.to_map(Error.new("gap"))})) ==
             {"invalid_field", "error"}

    assert error_code(check(Receipt, %{receipt() | "disposition" => "maybe"})) ==
             {"invalid_field", "disposition"}

    assert error_code(check(Receipt, %{receipt() | "command_id" => "bad"})) ==
             {"invalid_id", "command_id"}

    assert {:error, [_ | _]} = Receipt.new(%{receipt() | "sequence" => 0})
  end

  test "Splode errors have closed portable maps" do
    map = Error.to_map(Error.new("not_found"))
    assert match?(%Zoi.Types.Map{}, Error.schema())
    assert Error.splode_error?()
    refute Error.error_class?()
    assert Error.keyword_list_options?()
    assert Exception.message(Error.new("not_found")) == "not_found"
    assert Error.new("not_found").stacktrace == nil
    assert {:ok, %Error{code: "not_found", field: nil}} = Error.from_map(map)

    assert error_code(Error.from_map(%{map | "code" => "exception"})) ==
             {"invalid_field", "code"}

    assert error_code(Error.from_map(%{map | "field" => "Bad Name"})) ==
             {"invalid_field", "field"}

    assert error_code(Error.from_map(%{map | "field" => 42})) ==
             {"invalid_field", "field"}

    assert error_code(Error.from_map(%{map | "field" => String.duplicate("x", 65)})) ==
             {"invalid_field", "field"}

    assert error_code(Error.from_map(%{map | "version" => 99})) ==
             {"unsupported_version", "version"}

    assert Error.from_zoi([]).code == "invalid_field"
    assert Error.from_zoi([%Zoi.Error{code: :custom, issue: nil, path: []}]).field == "shape"
  end

  test "Views keep bounded revision and content values" do
    assert :ok = check(View, view())
    assert {:ok, signal} = View.new(view())
    assert signal.data == view()
    assert :ok = check(View, %{view() | "agent_revision" => 0, "lifecycle" => "closed"})
    assert :ok = check(View, %{view() | "lifecycle" => "closing"})

    for {field, value} <- [
          {"session_revision", -1},
          {"agent_revision", -1},
          {"event_cursor", -1},
          {"lifecycle", "paused"},
          {"content", []}
        ] do
      assert {"invalid_field", ^field} =
               error_code(check(View, Map.put(view(), field, value)))
    end

    assert error_code(check(View, %{view() | "content" => %{"pid" => self()}})) ==
             {"invalid_field", "content"}

    assert error_code(
             check(
               View,
               put_in(
                 view(),
                 ["content", "recent_outcomes"],
                 List.duplicate(
                   %{"command_id" => @command_id, "state" => "completed", "sequence" => 7},
                   11
                 )
               )
             )
           ) == {"invalid_field", "content"}

    assert error_code(check(View, put_in(view(), ["content", "extra"], true))) ==
             {"invalid_field", "content"}

    assert error_code(check(View, put_in(view(), ["content", "last_result_command_id"], nil))) ==
             {"invalid_field", "content"}

    ascending = [
      %{"command_id" => @command_id, "state" => "completed", "sequence" => 6},
      %{
        "command_id" => "cmd_018f1a1a-7b3c-7a00-8000-000000000004",
        "state" => "failed",
        "sequence" => 7
      }
    ]

    assert error_code(check(View, put_in(view(), ["content", "recent_outcomes"], ascending))) ==
             {"invalid_field", "content"}

    assert {:error, [_ | _]} = View.new(%{view() | "content" => %{"pid" => self()}})
  end

  test "portable values reject process values and excessive size or depth" do
    assert Value.check(%{"ok" => [nil, true, false, -5, 1, "text"]}) == :ok
    assert Value.check(%{"limit" => 9_007_199_254_740_991}) == :ok
    assert Value.check(%{"limit" => 9_007_199_254_740_992}) == {:error, "too_large"}
    assert Value.check(%{"text" => String.duplicate("x", 8_193)}) == {:error, "too_large"}
    assert Value.check(%{"text" => <<255>>}) == {:error, "invalid_field"}
    assert Value.check(%{"list" => Enum.to_list(1..65)}) == {:error, "too_large"}
    assert Value.check(%{"list" => [self()]}) == {:error, "invalid_field"}
    assert Value.check(Map.new(1..33, fn n -> {"k#{n}", n} end)) == {:error, "too_large"}

    assert Value.check(%{
             "a" => String.duplicate("a", 8_192),
             "b" => String.duplicate("b", 8_192)
           }) ==
             {:error, "too_large"}

    assert Value.check(%{
             "a" => String.duplicate("a", 8_192),
             "b" => String.duplicate("b", 8_189),
             "c" => nil
           }) ==
             {:error, "too_large"}

    assert Value.check(%{"deep" => %{"a" => %{"b" => %{"c" => %{"d" => 1}}}}}) ==
             {:error, "invalid_field"}

    for value <- [self(), make_ref(), fn -> :ok end, :atom, {1, 2}, 1.5] do
      assert Value.check(%{"bad" => value}) == {:error, "invalid_field"}
    end

    assert Value.check(%{atom: "bad"}) == {:error, "invalid_field"}
    assert Value.check(%{"" => "bad"}) == {:error, "invalid_field"}
    assert Value.check(%{String.duplicate("x", 65) => "bad"}) == {:error, "invalid_field"}
    assert Value.check(%{<<255>> => "bad"}) == {:error, "invalid_field"}
  end

  test "Updates carry only the closed remote event union" do
    assert :ok = check(Update, update())
    assert {:ok, signal} = Update.new(update())
    assert signal.data == update()
    result_id = String.replace_prefix(@command_id, "cmd_", "res_")

    for {event_type, payload} <- [
          {"command_completed", %{"result_id" => result_id}},
          {"command_failed", %{"reason" => "execution_failed", "result_id" => result_id}},
          {"command_failed", %{"reason" => "dispatch_unavailable", "result_id" => result_id}},
          {"command_failed", %{"reason" => "admission_rejected", "result_id" => result_id}},
          {"command_uncertain", %{"reason" => "agent_state_unknown", "result_id" => result_id}},
          {"command_uncertain", %{"reason" => "server_restarted", "result_id" => result_id}}
        ] do
      assert :ok = check(Update, %{update() | "event_type" => event_type, "payload" => payload})
    end

    for invalid <- [
          %{update() | "sequence" => 0},
          %{update() | "event_type" => "other_event"},
          %{update() | "command_id" => nil},
          %{update() | "command_id" => "bad"},
          %{update() | "payload" => %{}},
          %{
            update()
            | "payload" => %{
                "kind" => "submit_text",
                "state" => "active",
                "extra" => true
              }
          },
          %{update() | "kind" => "gap"},
          gap()
        ] do
      assert {:error, %Error{}} = check(Update, invalid)
    end

    assert {:error, [_ | _]} = Update.new(%{update() | "event_type" => "other_event"})

    compacted = %{
      update()
      | "sequence" => 9,
        "event_type" => "context_compacted",
        "command_id" => nil,
        "payload" => %{
          "config_revision" => 1,
          "previous_context_revision" => 0,
          "context_revision" => 1,
          "source_from_sequence" => 1,
          "source_to_sequence" => 8,
          "preserved_turns" => 1,
          "estimated_tokens_before" => 2_000,
          "estimated_tokens_after" => 700,
          "reason" => "threshold"
        }
    }

    assert :ok = check(Update, compacted)

    assert {"invalid_field", "payload"} =
             error_code(check(Update, put_in(compacted, ["payload", "context_revision"], 2)))
  end

  test "Update and History pages enforce item order, identity, and cursor coherence" do
    result_id = String.replace_prefix(@command_id, "cmd_", "res_")

    second_update = %{
      update()
      | "sequence" => 9,
        "event_type" => "command_completed",
        "payload" => %{"result_id" => result_id}
    }

    page = %{updates_page() | "updates" => [hd(updates_page()["updates"]), second_update]}
    assert :ok = check(UpdatesPage, %{page | "next_cursor" => 9})

    assert {"invalid_field", "updates"} =
             error_code(
               check(
                 UpdatesPage,
                 put_in(page, ["updates", Access.at(1), "session_id"], @other_session_id)
               )
             )

    assert {"invalid_field", "updates"} =
             error_code(check(UpdatesPage, %{page | "updates" => Enum.reverse(page["updates"])}))

    assert {"invalid_field", "updates"} =
             error_code(check(UpdatesPage, %{page | "after_sequence" => 6}))

    assert {"invalid_field", "next_cursor"} =
             error_code(check(UpdatesPage, %{page | "next_cursor" => 8}))

    assert {"invalid_field", "updates"} =
             error_code(
               check(UpdatesPage, %{page | "updates" => List.duplicate(hd(page["updates"]), 101)})
             )

    assert :ok = check(HistoryPage, history_page())

    assert {"invalid_field", "entries"} =
             error_code(
               check(
                 HistoryPage,
                 update_in(
                   history_page(),
                   ["entries", Access.at(0)],
                   &Map.delete(&1, "command_id")
                 )
               )
             )

    assert {"invalid_field", "entries"} =
             error_code(
               check(
                 HistoryPage,
                 put_in(history_page(), ["entries", Access.at(1), "sequence"], 3)
               )
             )

    assert {"invalid_field", "next_cursor"} =
             error_code(check(HistoryPage, %{history_page() | "next_cursor" => 1}))

    empty_updates = %{updates_page() | "updates" => [], "next_cursor" => nil}
    assert :ok = check(UpdatesPage, empty_updates)

    assert {"invalid_field", "next_cursor"} =
             error_code(check(UpdatesPage, %{empty_updates | "next_cursor" => 0}))

    empty_history = %{history_page() | "entries" => [], "next_cursor" => nil}
    assert :ok = check(HistoryPage, empty_history)

    assert {"invalid_field", "next_cursor"} =
             error_code(check(HistoryPage, %{empty_history | "next_cursor" => 0}))
  end

  test "live Progress is bounded, portable, and checked after decode" do
    assert {:ok, signal} = Progress.new(progress())
    assert {:ok, wire} = Jido.Signal.serialize(signal)
    assert {:ok, decoded} = Jido.Signal.deserialize(wire)
    assert {:ok, ^decoded} = Seigyo.validate(decoded)

    assert {"too_large", "text"} =
             error_code(check(Progress, %{progress() | "text" => String.duplicate("x", 16_385)}))

    assert {"too_large", "thinking"} =
             error_code(
               check(Progress, %{progress() | "thinking" => String.duplicate("x", 16_385)})
             )

    assert {"invalid_field", "phase"} =
             error_code(check(Progress, %{progress() | "phase" => "unknown"}))

    assert {"invalid_id", "command_id"} =
             error_code(Seigyo.validate(%{signal | data: %{progress() | "command_id" => "bad"}}))
  end

  test "each custom Signal survives JSON and is checked after decode" do
    for {module, data, source} <- [
          {Command, command(), "/jido/code/client"},
          {Receipt, rejected_receipt(), "/jido/code/server"},
          {View, view(), "/jido/code/server"},
          {Update, update(), "/jido/code/server"},
          {UpdatesPage, updates_page(), "/jido/code/server"},
          {Failure, Error.to_map(Error.new("conflict", "id")), "/jido/code/server"},
          {ExecutionCatalog, execution_catalog(), "/jido/code/server"},
          {Progress, progress(), "/jido/code/server"},
          {ResyncRequired, %{"version" => 1, "session_id" => @session_id}, "/jido/code/server"}
        ] do
      assert Jido.Signal.defined?(module)
      assert module.schema() != nil
      assert {:ok, signal} = module.new(data)
      assert signal.source == source
      assert signal.data == data
      assert Jido.Signal.ID.valid?(signal.id)
      assert {:ok, wire} = Jido.Signal.serialize(signal)
      assert {:ok, decoded} = Jido.Signal.deserialize(wire)
      assert {:ok, ^decoded} = Seigyo.validate(decoded)
    end
  end

  defp execution_catalog do
    %{
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
    }
  end

  test "a retry keeps its command ID and gets a new Signal ID" do
    assert {:ok, first} = Command.new(command())
    assert {:ok, second} = Command.new(command())
    refute first.id == second.id
    assert first.data["id"] == second.data["id"]
    assert first.type == Command.type()
  end

  test "decoded Signals reject altered data and unknown types" do
    assert {:ok, valid_signal} = Command.new(command())

    assert error_code(Seigyo.validate(%{valid_signal | data: %{command() | "kind" => "bad"}})) ==
             {"invalid_field", "kind"}

    for {module, valid, invalid, field} <- [
          {Receipt, receipt(), %{receipt() | "sequence" => 0}, "sequence"},
          {View, view(), %{view() | "content" => %{"pid" => self()}}, "content"},
          {Update, update(), %{update() | "event_type" => "Bad Name"}, "event_type"},
          {UpdatesPage, updates_page(), %{updates_page() | "next_cursor" => -1}, "next_cursor"}
        ] do
      assert {:ok, signal} = module.new(valid)

      assert {"invalid_field", ^field} =
               error_code(Seigyo.validate(%{signal | data: invalid}))
    end

    assert error_code(Seigyo.validate(%{valid_signal | type: "other"})) ==
             {"invalid_field", "type"}

    assert error_code(Seigyo.validate(nil)) == {"invalid_field", "type"}
  end
end
