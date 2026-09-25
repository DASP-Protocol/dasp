defmodule Jido.Seigyo.Client.Workspaces do
  @moduledoc "The configured Workspaces visible to the client principal."

  alias Jido.Seigyo.Client.{Value, Workspace}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(Jido.Seigyo.Workspaces.schema(), ~w(workspaces)a,
              projections: %{workspaces: Workspace.schema()}
            )
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Workspaces.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, workspaces} <- parse_workspaces(data["workspaces"]) do
      Value.parse(@schema, %__MODULE__{workspaces: workspaces})
    end
  end

  defp parse_workspaces(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case Workspace.from_data(value) do
        {:ok, workspace} -> {:cont, {:ok, [workspace | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, workspaces} -> {:ok, Enum.reverse(workspaces)}
      error -> error
    end
  end

  defp parse_workspaces(values), do: Value.invalid(values)
end
