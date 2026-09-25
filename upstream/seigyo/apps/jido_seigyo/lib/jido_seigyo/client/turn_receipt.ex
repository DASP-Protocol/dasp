defmodule Jido.Seigyo.Client.TurnReceipt do
  @moduledoc "The stable admission result for one coding turn."

  alias Jido.Seigyo.Client.Value
  alias Jido.Seigyo.Error

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.TurnReceipt.schema(),
              ~w(command_id session_id disposition state session_revision sequence error)a,
              projections: %{error: Zoi.struct(Error) |> Zoi.nullable()}
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.TurnReceipt.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, error} <- parse_error(data["error"]) do
      Value.parse(@schema, %__MODULE__{
        command_id: data["command_id"],
        session_id: data["session_id"],
        disposition: data["disposition"],
        state: data["state"],
        session_revision: data["session_revision"],
        sequence: data["sequence"],
        error: error
      })
    end
  end

  defp parse_error(nil), do: {:ok, nil}
  defp parse_error(value), do: Error.from_map(value)
end
