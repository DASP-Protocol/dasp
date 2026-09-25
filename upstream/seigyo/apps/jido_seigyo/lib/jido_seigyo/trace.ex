defmodule Jido.Seigyo.Trace do
  @moduledoc "The version 1 request trace Signal for Jido Code clients."

  @statuses ~w(accepted dispatched completed failed cancelled uncertain)
  @terminal_statuses ~w(completed failed cancelled uncertain)

  use Jido.Signal,
    type: "jido.client.v1.trace",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "model_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :model, []})
            |> Zoi.nullable(),
          "config_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "config_digest" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []}),
          "tool_profile" => Jido.Seigyo.SessionConfig.tool_profile_schema(),
          "status" => Zoi.enum(@statuses),
          "failure_reason" => Zoi.string() |> Zoi.max(100) |> Zoi.nullable(),
          "duration_ms" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            |> Zoi.nullable(),
          "model_calls" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "input_tokens" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "output_tokens" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "truncated" => Zoi.boolean(),
          "tools" => Zoi.list(Jido.Seigyo.Tool.schema()) |> Zoi.max(100),
          "thinking" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :progress_text, []}),
          "thinking_truncated" => Zoi.boolean()
        },
        unrecognized_keys: :error
      )

  @doc "Returns every closed coding v1 Trace status."
  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  @doc "Checks whether a Trace status settles its Command."
  @spec terminal_status?(term()) :: boolean()
  def terminal_status?(status), do: status in @terminal_statuses
end
