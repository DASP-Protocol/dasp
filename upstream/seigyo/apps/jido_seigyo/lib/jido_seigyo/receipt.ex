defmodule Jido.Seigyo.Receipt do
  @moduledoc "The version 1 command receipt Signal."

  @common_fields %{
    "version" => Zoi.literal(1),
    "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []})
  }
  @accepted_fields %{
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
    type: "jido.client.v1.receipt",
    default_source: "/jido/code/server",
    schema:
      Zoi.discriminated_union("disposition", [
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@accepted_fields, "disposition", Zoi.literal("accepted"))
          ),
          unrecognized_keys: :error
        ),
        Zoi.object(
          Map.merge(
            @common_fields,
            Map.put(@accepted_fields, "disposition", Zoi.literal("duplicate"))
          ),
          unrecognized_keys: :error
        ),
        Zoi.object(
          Map.merge(@common_fields, %{
            "disposition" => Zoi.literal("rejected"),
            "session_revision" => Zoi.literal(nil),
            "sequence" => Zoi.literal(nil),
            "error" => Jido.Seigyo.Error.schema()
          }),
          unrecognized_keys: :error
        )
      ])
end
