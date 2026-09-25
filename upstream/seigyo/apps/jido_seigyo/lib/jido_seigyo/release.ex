defmodule Jido.Seigyo.Release do
  @moduledoc """
  Generates the machine-readable contract for the coding v1 release bundle.

  This module contains data only. It does not start a server or use a transport.
  """

  alias Jido.Seigyo
  alias Jido.Seigyo.Catalog

  @id_patterns Jido.Seigyo.ID.patterns()

  @spec signal_modules() :: [{:request | :result | :push, module()}]
  def signal_modules, do: Catalog.signals()

  @spec manifest() :: map()
  def manifest do
    %{
      "version" => Seigyo.version(),
      "profile" => Seigyo.profile(),
      "status" => "coding-v1-local-release-bundle",
      "transport" => transport(),
      "capabilities" => Seigyo.capabilities("$authenticated-principal"),
      "operations" => operation_contracts(),
      "controls" => controls(),
      "events" =>
        Enum.map(Catalog.events(), fn event ->
          %{
            "name" => event.name,
            "signal_type" => event.signal.type(),
            "role" => "event",
            "direction" => "server_to_client",
            "authority" => Atom.to_string(event.authority),
            "requirements" => ["SEIGYO-DEFINITION-002"]
          }
        end),
      "errors" => errors(),
      "limits" => limits(),
      "validation" => validation()
    }
  end

  @spec schemas() :: map()
  def schemas do
    signals =
      Map.new(Catalog.signals(), fn {role, module} ->
        type = module.type()

        {type,
         %{
           "role" => Atom.to_string(role),
           "schema" => envelope_schema(role, type, module.schema())
         }}
      end)

    %{
      "version" => Seigyo.version(),
      "profile" => Seigyo.profile(),
      "dialect" => "https://json-schema.org/draft/2020-12/schema",
      "signals" => signals
    }
  end

  @spec frames() :: map()
  def frames do
    %{
      "version" => Seigyo.version(),
      "profile" => Seigyo.profile(),
      "frame_shape" => ["join_ref", "ref", "topic", "event", "payload"],
      "join" => %{
        "request" => ["1", "1", "client:v1", "phx_join", %{"version" => 1, "profile" => "coding"}],
        "reply" => [
          "1",
          "1",
          "client:v1",
          "phx_reply",
          %{
            "status" => "ok",
            "response" => %{"$capabilities" => "manifest.capabilities"}
          }
        ]
      },
      "invalid_session" => %{
        "request" => [
          "1",
          "2",
          "client:v1",
          "call",
          %{
            "op" => "view",
            "request_ref" => "fixture-invalid-session",
            "args" => %{"session_id" => "bad-session"}
          }
        ],
        "reply" => [
          "1",
          "2",
          "client:v1",
          "phx_reply",
          %{
            "status" => "error",
            "response" => %{
              "request_ref" => "fixture-invalid-session",
              "failure" => %{
                "specversion" => "1.0",
                "id" => "$dynamic-signal-id",
                "source" => "/jido/code/server",
                "type" => "jido.client.v1.failure",
                "data" => %{"version" => 1, "code" => "invalid_id", "field" => "session_id"}
              }
            }
          }
        ]
      },
      "controls" => %{
        "watch_progress" => [
          "1",
          "$ref",
          "client:v1",
          "watch_progress",
          %{"request_ref" => "$request-ref", "session_id" => "$session-id"}
        ],
        "watch_updates" => [
          "1",
          "$ref",
          "client:v1",
          "watch_updates",
          %{
            "request_ref" => "$request-ref",
            "session_id" => "$session-id",
            "after_sequence" => "$last-applied-sequence"
          }
        ]
      },
      "pushes" => %{
        "progress" => [
          nil,
          nil,
          "client:v1",
          "progress",
          %{"$signal" => "jido.client.v1.progress"}
        ],
        "update" => [nil, nil, "client:v1", "update", %{"$signal" => "jido.client.v1.update"}],
        "resync_required" => [
          nil,
          nil,
          "client:v1",
          "resync_required",
          %{"$signal" => "jido.client.v1.resync.required"}
        ]
      }
    }
  end

  defp operation_contracts do
    Enum.map(Catalog.operations(), fn operation ->
      name = operation.name
      request_module = operation.request

      %{
        "name" => name,
        "input" => if(request_module, do: "signal", else: "args"),
        "payload_keys" =>
          if(request_module,
            do: ["op", "request_ref", "signal"],
            else: ["args", "op", "request_ref"]
          ),
        "request_signal_type" => request_module && request_module.type(),
        "args_schema" => operation.args_schema,
        "result_signal_type" => operation.result.type(),
        "reply_role" => "reply",
        "failure_delivery" => operation.failure_delivery,
        "role" => "request",
        "direction" => Atom.to_string(operation.direction),
        "profile" => operation.profile,
        "retry" => Atom.to_string(operation.retry),
        "failures" => operation.failures,
        "requirements" => operation.requirements,
        "conformance_cases" => operation.conformance_cases
      }
    end)
  end

  defp controls do
    Enum.map(Catalog.controls(), fn control ->
      contract = %{
        "name" => control.name,
        "payload_keys" => Enum.sort(control.arguments),
        "args_schema" => control.args_schema,
        "reply" => control.reply,
        "requirements" => control.requirements,
        "conformance_cases" => control.conformance_cases
      }

      contract =
        case control.push_events do
          [event] -> Map.put(contract, "push_event", event)
          events -> Map.put(contract, "push_events", events)
        end

      put_control_push_signals(contract, control.push_signals)
    end)
  end

  defp put_control_push_signals(contract, [signal_module]) do
    Map.put(contract, "push_signal_type", signal_module.type())
  end

  defp put_control_push_signals(contract, signal_modules) do
    Map.put(contract, "push_signal_types", Enum.map(signal_modules, & &1.type()))
  end

  defp transport do
    %{
      "name" => "phoenix-channel-websocket",
      "phoenix_version" => "2.0.0",
      "route" => "/client/socket/websocket",
      "topic" => "client:v1",
      "join_event" => "phx_join",
      "reply_event" => "phx_reply",
      "call_event" => "call",
      "frame_shape" => ["join_ref", "ref", "topic", "event", "payload"],
      "http" => false
    }
  end

  defp errors do
    %{
      "invalid_session" => %{"code" => "invalid_id", "field" => "session_id"},
      "invalid_command" => %{"code" => "invalid_id", "field" => "command_id"},
      "invalid_target_command" => %{"code" => "invalid_id", "field" => "target_command_id"},
      "invalid_cursor" => %{"code" => "invalid_field", "field" => "after_sequence"},
      "invalid_revision_cursor" => %{"code" => "invalid_field", "field" => "after_revision"},
      "invalid_limit" => %{"code" => "invalid_field", "field" => "limit"},
      "unknown_session" => %{"code" => "not_found", "field" => "session_id"},
      "unknown_command" => %{"code" => "not_found", "field" => "command_id"},
      "missing_workspace_root" => %{"code" => "unavailable", "field" => "workspace_root"}
    }
  end

  defp limits do
    contract = Jido.Seigyo.Contract

    %{
      "websocket_frame_bytes" => contract.websocket_frame_bytes_limit(),
      "signal_json_bytes" => contract.signal_json_bytes_limit(),
      "updates_page_json_bytes" => contract.updates_page_json_bytes_limit(),
      "request_ref_bytes" => contract.request_ref_bytes_limit(),
      "page_items" => contract.page_items_limit(),
      "json_integer_max" => contract.max_json_integer(),
      "command_text_bytes" => 8_192,
      "progress_text_bytes" => contract.progress_text_limit(),
      "history_text_bytes" => contract.history_text_limit(),
      "workspace_patch_bytes" => contract.workspace_patch_limit(),
      "session_instructions_bytes" => contract.session_instructions_limit(),
      "result_text_bytes" => contract.result_text_limit(),
      "result_blocks_json_bytes" => contract.result_blocks_bytes_limit(),
      "attachment_chunk_decoded_bytes" => contract.attachment_chunk_limit(),
      "attachment_bytes" => contract.attachment_size_limit()
    }
  end

  defp validation do
    %{
      "closed_objects" => true,
      "unknown_signal_types" => "reject",
      "custom_refinements" => custom_refinements(),
      "id_patterns" => @id_patterns,
      "request_ref" => %{
        "min_utf8_bytes" => 1,
        "max_utf8_bytes" => Jido.Seigyo.Contract.request_ref_bytes_limit(),
        "control_characters" => false,
        "unique_while_active" => true
      },
      "json_values" => %{
        "map_keys" => "string",
        "floats" => false,
        "atoms_or_runtime_values" => false
      }
    }
  end

  defp custom_refinements do
    [
      %{
        "id" => "utf8-byte-length",
        "applies_to" => "bounded strings and request_ref",
        "rule" => "Limits use encoded UTF-8 bytes, not Unicode character count.",
        "error_code" => "too_large"
      },
      %{
        "id" => "portable-json-tree",
        "applies_to" => "metadata, result blocks, and open values",
        "rule" =>
          "Values contain only JSON objects with string keys, arrays, strings, booleans, null, and safe integers within the published limits.",
        "error_code" => "invalid_field"
      },
      %{
        "id" => "cross-field-coherence",
        "applies_to" => "Signals with related identifiers, states, or ranges",
        "rule" =>
          "Related fields must identify one coherent protocol object and state transition.",
        "error_code" => "invalid_field"
      },
      %{
        "id" => "ordered-page",
        "applies_to" => "updates, history, and configuration history pages",
        "rule" =>
          "Page entries are strictly ordered and cursor fields describe the returned range.",
        "error_code" => "invalid_field"
      }
    ]
  end

  defp envelope_schema(role, type, data_schema) do
    source = if role == :request, do: "/jido/code/client", else: "/jido/code/server"

    %{
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "type" => "object",
      "additionalProperties" => false,
      "required" => ~w(specversion id source type data),
      "properties" => %{
        "specversion" => %{"const" => "1.0"},
        "id" => %{"type" => "string", "pattern" => @id_patterns["signal"]},
        "source" => %{"const" => source},
        "type" => %{"const" => type},
        "data" => normalize_schema(data_schema)
      }
    }
  end

  defp normalize_schema(schema) do
    schema
    |> Zoi.to_json_schema()
    |> Map.delete(:"$schema")
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
