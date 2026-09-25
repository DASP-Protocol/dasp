defmodule Jido.Seigyo.Client.Session do
  @moduledoc "A Session opened through the Jido Code client."

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.SessionOpened.schema(),
            ~w(id workspace_id protocol_version protocol_profile)a,
            paths: %{id: "session_id"}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionOpened.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    Jido.Seigyo.Client.Value.parse(
      @schema,
      %__MODULE__{
        id: data["session_id"],
        workspace_id: data["workspace_id"],
        protocol_version: data["protocol_version"],
        protocol_profile: data["protocol_profile"]
      }
    )
  end
end
