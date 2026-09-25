defmodule Jido.Seigyo.Client.TurnControlled do
  @moduledoc "The stable result of one steering or cancellation mutation."

  alias Jido.Seigyo.Client.Value

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.TurnControlled.schema(),
              ~w(mutation_id session_id target_command_id action disposition sequence)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.TurnControlled.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    Value.parse(@schema, %__MODULE__{
      mutation_id: data["mutation_id"],
      session_id: data["session_id"],
      target_command_id: data["target_command_id"],
      action: data["action"],
      disposition: data["disposition"],
      sequence: data["sequence"]
    })
  end
end
