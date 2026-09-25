defmodule Jido.Seigyo.Client.Message do
  @moduledoc "One bounded message in a Session view."

  @fields Jido.Seigyo.Schema.fields(Jido.Seigyo.View.message_schema(), ~w(command_id role text)a)
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.View.message_schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    Jido.Seigyo.Client.Value.parse(
      @schema,
      %__MODULE__{command_id: data["command_id"], role: data["role"], text: data["text"]}
    )
  end
end
