defmodule Jido.Seigyo.TurnCancel do
  @moduledoc "A request to cancel one active or queued coding turn."

  use Jido.Signal,
    type: "jido.client.v1.turn.cancel",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "target_command_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "reason" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :history_text, []})
            |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
end
