defmodule DASP.Signal.Failure do
  @moduledoc "The draft-01 `dasp.v1.failure` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.failure",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "error" => Fields.error()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.failure"]})
end
