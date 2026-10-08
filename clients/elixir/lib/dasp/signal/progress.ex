defmodule DASP.Signal.Progress do
  @moduledoc "The draft-01 `dasp.v1.progress` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.progress",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "command_id" => Fields.identifier() |> Zoi.nullable(),
          "name" => Fields.name(),
          "payload" => Fields.json_object()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.progress"]})
end
