defmodule Jido.Seigyo.Client.ResyncRequired do
  @moduledoc "A typed notice that requires replay from the last saved Update cursor."

  @fields Jido.Seigyo.Schema.fields(Jido.Seigyo.ResyncRequired.schema(), ~w(session_id)a)
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(%{"version" => 1, "session_id" => session_id} = data)
      when map_size(data) == 2 do
    Jido.Seigyo.Client.Value.parse(@schema, %__MODULE__{session_id: session_id})
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)
end
