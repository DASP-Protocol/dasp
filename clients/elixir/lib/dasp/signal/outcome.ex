defmodule DASP.Signal.Outcome do
  @moduledoc "The draft-01 `dasp.v1.outcome` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  @result Zoi.union([
            Zoi.map(
              %{
                "status" => Zoi.literal("completed"),
                "output" => Fields.json_object(),
                "error" => Zoi.literal(nil)
              },
              unrecognized_keys: :error
            ),
            Zoi.map(
              %{
                "status" => Zoi.enum(["failed", "uncertain"]),
                "output" => Fields.json_object() |> Zoi.nullable(),
                "error" => Fields.error()
              },
              unrecognized_keys: :error
            ),
            Zoi.map(
              %{
                "status" => Zoi.literal("cancelled"),
                "output" => Fields.json_object() |> Zoi.nullable(),
                "error" => Zoi.literal(nil)
              },
              unrecognized_keys: :error
            )
          ])
  @doc false
  def result_schema, do: @result

  use Jido.Signal,
    type: "dasp.v1.outcome",
    datacontenttype: "application/json",
    schema:
      Zoi.union([
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "command_id" => Fields.identifier(),
            "state" => Zoi.literal("pending"),
            "sequence" => Zoi.literal(nil),
            "outcome" => Zoi.literal(nil)
          },
          unrecognized_keys: :error
        ),
        Zoi.map(
          %{
            "session_id" => Fields.identifier(),
            "command_id" => Fields.identifier(),
            "state" => Zoi.literal("settled"),
            "sequence" => Fields.sequence(),
            "outcome" => @result
          },
          unrecognized_keys: :error
        )
      ])
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.outcome"]})
end
