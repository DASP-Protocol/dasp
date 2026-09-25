defmodule Jido.Seigyo.Client.Tool do
  @moduledoc "One bounded tool activity summary in a command trace."

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.Tool.schema(),
            ~w(id name status duration_ms truncated summary)a
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Tool.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    Jido.Seigyo.Client.Value.parse(
      @schema,
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        status: data["status"],
        duration_ms: data["duration_ms"],
        truncated: data["truncated"],
        summary: data["summary"]
      }
    )
  end
end
