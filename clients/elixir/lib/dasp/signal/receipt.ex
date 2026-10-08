defmodule DASP.Signal.Receipt do
  @moduledoc "The draft-01 `dasp.v1.receipt` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.receipt",
    datacontenttype: "application/json",
    schema:
      Zoi.union([
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "command_id" => Fields.identifier(),
            "disposition" => Zoi.enum(["accepted", "duplicate"]),
            "admission_sequence" => Fields.sequence(),
            "error" => Zoi.literal(nil)
          },
          unrecognized_keys: :error
        ),
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "command_id" => Fields.identifier(),
            "disposition" => Zoi.literal("rejected"),
            "admission_sequence" => Zoi.literal(nil),
            "error" => Fields.error()
          },
          unrecognized_keys: :error
        )
      ])
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.receipt"]})
end
