defmodule Jido.Seigyo.Progress do
  @moduledoc "A bounded, live activity snapshot for one active client command."

  use Jido.Signal,
    type: "jido.client.v1.progress",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "sequence" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "iteration" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "phase" => Zoi.enum(~w(working thinking writing using_tools finishing)),
          "text" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :progress_text, []}),
          "truncated" => Zoi.boolean(),
          "thinking" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :progress_text, []}),
          "thinking_truncated" => Zoi.boolean(),
          "tools" => Zoi.list(Jido.Seigyo.Tool.schema()) |> Zoi.max(24),
          "tools_truncated" => Zoi.boolean()
        },
        unrecognized_keys: :error
      )
end
