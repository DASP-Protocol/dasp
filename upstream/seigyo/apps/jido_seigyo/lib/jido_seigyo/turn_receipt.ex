defmodule Jido.Seigyo.TurnReceipt do
  @moduledoc "The admission result for one queued coding turn."

  @common_fields %{
    "version" => Zoi.literal(1),
    "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []})
  }
  @admitted_fields %{
    "state" => Zoi.enum(~w(active queued)),
    "session_revision" =>
      Zoi.integer()
      |> Zoi.min(0)
      |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
    "sequence" =>
      Zoi.integer()
      |> Zoi.min(1)
      |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
    "error" => Zoi.literal(nil)
  }

  use Jido.Signal,
    type: "jido.client.v1.turn.receipt",
    default_source: "/jido/code/server",
    schema:
      Zoi.discriminated_union("disposition", [
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@admitted_fields, "disposition", Zoi.literal("accepted"))
          ),
          unrecognized_keys: :error
        ),
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@admitted_fields, "disposition", Zoi.literal("duplicate"))
          ),
          unrecognized_keys: :error
        ),
        Zoi.object(
          Map.merge(@common_fields, %{
            "disposition" => Zoi.literal("rejected"),
            "state" => Zoi.literal(nil),
            "session_revision" => Zoi.literal(nil),
            "sequence" => Zoi.literal(nil),
            "error" => Jido.Seigyo.Error.schema()
          }),
          unrecognized_keys: :error
        )
      ])
end
