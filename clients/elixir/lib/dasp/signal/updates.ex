defmodule DASP.Signal.Updates do
  @moduledoc "The draft-01 `dasp.v1.updates` signal. Data keys are strings."
  alias DASP.Signal.{Fields, Validation}

  use Jido.Signal,
    type: "dasp.v1.updates",
    datacontenttype: "application/json",
    schema:
      Zoi.map(
        %{
          "session_id" => Fields.identifier(),
          "after" => Fields.cursor(),
          "next" => Fields.cursor(),
          "head" => Fields.cursor(),
          "events" =>
            Zoi.intersection([
              Zoi.any() |> Zoi.refine({__MODULE__, :proper_events_list, []}),
              Zoi.array(Zoi.any() |> Zoi.refine({__MODULE__, :saved_update, []})) |> Zoi.max(100)
            ])
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Validation, :data_limits, ["dasp.v1.updates"]})

  @doc false
  def proper_events_list(value, _) when is_list(value) do
    _ = length(value)
    :ok
  rescue
    ArgumentError -> {:error, "Expected a proper events list."}
  end

  def proper_events_list(_, _), do: :ok

  @doc false
  def saved_update(value, _) do
    event = DASP.Wire.to_signal!(value)
    if event.type == "dasp.v1.update", do: :ok, else: {:error, "Expected a saved Update event."}
  rescue
    _ -> {:error, "Invalid saved Update event."}
  end
end
