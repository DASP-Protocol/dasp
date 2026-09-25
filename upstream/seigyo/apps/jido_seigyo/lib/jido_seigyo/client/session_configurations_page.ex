defmodule Jido.Seigyo.Client.SessionConfigurationsPage do
  @moduledoc "One bounded page of saved Session configuration revisions."

  alias Jido.Seigyo.Client.{SessionConfig, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfigurationsPage.schema(),
              ~w(session_id oldest_revision after_revision configurations next_cursor)a,
              projections: %{configurations: SessionConfig.schema()}
            )
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionConfigurationsPage.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, configurations} <- configurations(data["configurations"]) do
      Value.parse(@schema, %__MODULE__{
        session_id: data["session_id"],
        oldest_revision: data["oldest_revision"],
        after_revision: data["after_revision"],
        configurations: configurations,
        next_cursor: data["next_cursor"]
      })
    end
  end

  defp configurations(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case SessionConfig.from_data(value) do
        {:ok, config} -> {:cont, {:ok, [config | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp configurations(value), do: Value.invalid(value)
end
