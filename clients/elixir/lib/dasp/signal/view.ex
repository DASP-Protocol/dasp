defmodule DASP.Signal.View do
  @moduledoc "The draft-01 `dasp.v1.view` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.view",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "actor_id" => Fields.identifier(),
          "profile" => Fields.profile(),
          "cursor" => Fields.cursor(),
          "state" => Fields.json_object()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.view"]})
end
