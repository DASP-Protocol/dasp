defmodule DASP.Signal.UpdatesRead do
  @moduledoc "The draft-01 `dasp.v1.updates.read` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.updates.read",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "after" => Fields.cursor(),
          "limit" => Zoi.integer() |> Zoi.gte(1) |> Zoi.lte(100)
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.updates.read"]})
end
