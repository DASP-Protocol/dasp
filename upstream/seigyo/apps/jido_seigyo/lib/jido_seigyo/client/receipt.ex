defmodule Jido.Seigyo.Client.Receipt do
  @moduledoc "The stable admission result for one command."

  alias Jido.Seigyo.Error, as: SeigyoError

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.Receipt.schema(),
            ~w(command_id session_id disposition session_revision sequence error)a,
            projections: %{error: Zoi.struct(SeigyoError) |> Zoi.nullable()}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)
          |> Zoi.refine(
            {Jido.Seigyo.Client.Value, :canonical, [Jido.Seigyo.Receipt, :schema, true]}
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Receipt.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, error} <- error_from_data(data["error"]) do
      value =
        %__MODULE__{
          command_id: data["command_id"],
          session_id: data["session_id"],
          disposition: data["disposition"],
          session_revision: data["session_revision"],
          sequence: data["sequence"],
          error: error
        }

      Jido.Seigyo.Client.Value.parse(@schema, value)
    end
  end

  defp error_from_data(nil), do: {:ok, nil}

  defp error_from_data(error) do
    case SeigyoError.from_map(error) do
      {:ok, value} -> {:ok, value}
      {:error, _error} -> Jido.Seigyo.Client.Value.invalid(:receipt_error)
    end
  end
end
