defmodule DASP.Signal.SessionOpen do
  @moduledoc "The draft-01 `dasp.v1.session.open` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.session.open",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "actor_id" => Fields.identifier(),
          "profile" => Fields.profile()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.session.open"]})
end
