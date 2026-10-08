defmodule DASP.Signal.Update do
  @moduledoc "The draft-01 `dasp.v1.update` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.update",
    datacontenttype: "application/json",
    schema:
      Zoi.union([
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "sequence" => Fields.sequence(),
            "kind" => Zoi.literal("command.accepted"),
            "command_id" => Fields.identifier(),
            "payload" =>
              Zoi.map(
                %{
                  "name" => Fields.name()
                },
                unrecognized_keys: :error
              )
          },
          unrecognized_keys: :error
        ),
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "sequence" => Fields.sequence(),
            "kind" => Zoi.literal("command.outcome"),
            "command_id" => Fields.identifier(),
            "payload" => DASP.Signal.Outcome.result_schema()
          },
          unrecognized_keys: :error
        ),
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "sequence" => Fields.sequence(),
            "kind" => Zoi.literal("application"),
            "command_id" => Fields.identifier() |> Zoi.nullable(),
            "payload" =>
              Zoi.map(
                %{
                  "name" => Fields.name(),
                  "data" => Fields.json_object()
                },
                unrecognized_keys: :error
              )
          },
          unrecognized_keys: :error
        )
      ])
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.update"]})
end
