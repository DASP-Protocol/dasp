defmodule Jido.Seigyo.Client.WorkspaceChanges do
  @moduledoc "The current bounded change set for a Session Workspace."

  alias Jido.Seigyo.Client.WorkspaceChange

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.WorkspaceChanges.schema(),
            ~w(session_id workspace_id base_revision clean files patch truncated)a,
            projections: %{files: WorkspaceChange.schema()}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.WorkspaceChanges.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, files} <- map_files(data["files"]) do
      Jido.Seigyo.Client.Value.parse(
        @schema,
        %__MODULE__{
          session_id: data["session_id"],
          workspace_id: data["workspace_id"],
          base_revision: data["base_revision"],
          clean: data["clean"],
          files: files,
          patch: data["patch"],
          truncated: data["truncated"]
        }
      )
    end
  end

  defp map_files(files) when is_list(files) do
    Enum.reduce_while(files, {:ok, []}, fn file, {:ok, acc} ->
      case WorkspaceChange.from_data(file) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp map_files(files), do: Jido.Seigyo.Client.Value.invalid(files)
end
