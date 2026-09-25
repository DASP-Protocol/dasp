defmodule Jido.Seigyo.Client.Workspace do
  @moduledoc "One configured Workspace returned by the Seigyo Protocol."

  alias Jido.Seigyo.Client.Value

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Workspace.schema(),
              ~w(id name file_path runtime_path ownership mode status version)a
            )
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Workspace.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    Value.parse(@schema, %__MODULE__{
      id: data["id"],
      name: data["name"],
      file_path: data["file_path"],
      runtime_path: data["runtime_path"],
      ownership: data["ownership"],
      mode: data["mode"],
      status: data["status"],
      version: data["version"]
    })
  end
end
