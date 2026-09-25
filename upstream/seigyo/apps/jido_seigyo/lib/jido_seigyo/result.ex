defmodule Jido.Seigyo.Result do
  @moduledoc "A normalized final Session result that hides internal orchestration."

  @json_integer Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
  @token_count Zoi.nullable(@json_integer)
  @usage_schema Zoi.object(
                  %{
                    "measurement" => Zoi.enum(~w(reported estimated mixed unavailable)),
                    "input_tokens" => @token_count,
                    "output_tokens" => @token_count,
                    "reasoning_tokens" => @token_count,
                    "cache_read_tokens" => @token_count,
                    "cache_write_tokens" => @token_count,
                    "model_calls" => @json_integer,
                    "delegated_runs" => @json_integer
                  },
                  unrecognized_keys: :error
                )
                |> Zoi.refine({Jido.Seigyo.Contract, :result_usage, []})
  @reasoning_schema Zoi.object(
                      %{
                        "visibility" => Zoi.enum(~w(hidden summary)),
                        "summary" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :progress_text, []})
                          |> Zoi.nullable(),
                        "truncated" => Zoi.boolean()
                      },
                      unrecognized_keys: :error
                    )
                    |> Zoi.refine({Jido.Seigyo.Contract, :reasoning, []})
  @block_schema Zoi.discriminated_union("type", [
                  Zoi.object(
                    %{
                      "type" => Zoi.literal("markdown"),
                      "text" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :result_text, []}),
                      "truncated" => Zoi.boolean()
                    },
                    unrecognized_keys: :error
                  ),
                  Zoi.object(
                    %{
                      "type" => Zoi.literal("attachment"),
                      "attachment_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []})
                    },
                    unrecognized_keys: :error
                  ),
                  Zoi.object(
                    %{
                      "type" => Zoi.literal("artifact"),
                      "artifact_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :artifact_id, []}),
                      "name" =>
                        Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
                      "media_type" =>
                        Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :media_type, []})
                    },
                    unrecognized_keys: :error
                  ),
                  Zoi.object(
                    %{
                      "type" => Zoi.literal("workspace_changes"),
                      "workspace_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []})
                    },
                    unrecognized_keys: :error
                  ),
                  Zoi.object(
                    %{
                      "type" => Zoi.literal("citation"),
                      "uri" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
                      "title" =>
                        Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []})
                    },
                    unrecognized_keys: :error
                  )
                ])

  use Jido.Signal,
    type: "jido.client.v1.result",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "result_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :result_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "completion" => Zoi.literal("execution"),
          "status" => Zoi.enum(~w(completed failed cancelled uncertain)),
          "config_revision" => @json_integer,
          "config_digest" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []}),
          "tool_profile" => Jido.Seigyo.SessionConfig.tool_profile_schema(),
          "context_revision" => @json_integer,
          "model_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :model, []})
            |> Zoi.nullable(),
          "blocks" => Zoi.list(@block_schema) |> Zoi.max(50),
          "usage" => @usage_schema,
          "reasoning" => @reasoning_schema,
          "error" => Jido.Seigyo.Error.schema() |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :result, []})

  @spec usage_schema() :: Zoi.schema()
  def usage_schema, do: @usage_schema

  @spec reasoning_schema() :: Zoi.schema()
  def reasoning_schema, do: @reasoning_schema

  @spec block_schema() :: Zoi.schema()
  def block_schema, do: @block_schema
end
