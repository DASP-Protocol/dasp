defmodule Jido.Seigyo.TurnControlled do
  @moduledoc "The idempotent result of one steer or cancel mutation."

  @common_fields %{
    "version" => Zoi.literal(1),
    "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
    "target_command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
    "action" => Zoi.enum(~w(steer cancel))
  }
  @applied_fields %{
    "sequence" =>
      Zoi.integer()
      |> Zoi.min(1)
      |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
  }

  use Jido.Signal,
    type: "jido.client.v1.turn.controlled",
    default_source: "/jido/code/server",
    schema:
      Zoi.discriminated_union("disposition", [
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@applied_fields, "disposition", Zoi.literal("applied"))
          ),
          unrecognized_keys: :error
        ),
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@applied_fields, "disposition", Zoi.literal("duplicate"))
          ),
          unrecognized_keys: :error
        )
      ])
end
