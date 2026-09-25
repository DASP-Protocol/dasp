defmodule Jido.Seigyo.TurnSteer do
  @moduledoc "A request to steer one active coding turn."

  @attachment_id Zoi.string()
                 |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []})

  use Jido.Signal,
    type: "jido.client.v1.turn.steer",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "target_command_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "text" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :text, []}),
          "attachment_ids" => Zoi.list(@attachment_id, unique_items: true) |> Zoi.max(32)
        },
        unrecognized_keys: :error
      )
end
