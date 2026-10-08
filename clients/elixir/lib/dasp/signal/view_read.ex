defmodule DASP.Signal.ViewRead do
  @moduledoc "The draft-01 `dasp.v1.view.read` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.view.read",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.view.read"]})
end
