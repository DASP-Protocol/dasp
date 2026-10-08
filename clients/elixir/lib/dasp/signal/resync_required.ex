defmodule DASP.Signal.ResyncRequired do
  @moduledoc "The draft-01 `dasp.v1.resync.required` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.resync.required",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "reason" => Zoi.enum(["overflow", "interrupted"]),
          "head" => Fields.cursor()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.resync.required"]})
end
