defmodule Jido.Seigyo.Client.WorkspaceConfigured do
  @moduledoc "The result of one Workspace configuration mutation."

  alias Jido.Seigyo.Client.{Value, Workspace}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.WorkspaceConfigured.schema(),
              ~w(mutation_id disposition workspace)a,
              projections: %{workspace: Workspace.schema()}
            )
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.WorkspaceConfigured.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, workspace} <- Workspace.from_data(data["workspace"]) do
      Value.parse(@schema, %__MODULE__{
        mutation_id: data["mutation_id"],
        disposition: data["disposition"],
        workspace: workspace
      })
    end
  end
end
