defmodule DASP.Signal.Command do
  @moduledoc "The draft-01 `dasp.v1.command` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.command",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "command_id" => Fields.identifier(),
          "name" => Fields.name(),
          "input" => Fields.json_object()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.command"]})
end
