defmodule Jido.Seigyo.Client.SessionMember do
  @moduledoc "A human or Jido Actor with durable access to one Session."

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.SessionMember.schema(),
            ~w(id actor_id actor_kind display_name role status revision)a
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionMember.schema(), data) do
      attrs = Map.new(@fields, fn {field, _} -> {field, data[Atom.to_string(field)]} end)
      Jido.Seigyo.Client.Value.parse(@schema, struct!(__MODULE__, attrs))
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)
end

defmodule Jido.Seigyo.Client.SessionMembers do
  @moduledoc "The active members and current revision of one Session."

  alias Jido.Seigyo.Client.{SessionMember, Value}

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.SessionMembers.schema(),
            ~w(session_id revision members)a,
            projections: %{members: SessionMember.schema()}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  def from_data(data) when is_map(data) do
    with {:ok, data} <- Value.parse(Jido.Seigyo.SessionMembers.schema(), data),
         {:ok, members} <- map_members(data["members"]) do
      Value.parse(
        @schema,
        %__MODULE__{
          session_id: data["session_id"],
          revision: data["revision"],
          members: members
        }
      )
    end
  end

  def from_data(data), do: Value.invalid(data)

  defp map_members(members) do
    Enum.reduce_while(members, {:ok, []}, fn data, {:ok, acc} ->
      case SessionMember.from_data(data) do
        {:ok, member} -> {:cont, {:ok, [member | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end

defmodule Jido.Seigyo.Client.MemberChanged do
  @moduledoc "The result of one Session membership mutation."

  alias Jido.Seigyo.Client.{SessionMember, Value}

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.MemberChanged.schema(),
            ~w(mutation_id session_id sequence previous_revision revision disposition action member)a,
            projections: %{member: SessionMember.schema()}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  def from_data(data) when is_map(data) do
    with {:ok, data} <- Value.parse(Jido.Seigyo.MemberChanged.schema(), data),
         {:ok, member} <- SessionMember.from_data(data["member"]) do
      attrs =
        Map.new(@fields, fn
          {:member, _} -> {:member, member}
          {field, _} -> {field, data[Atom.to_string(field)]}
        end)

      Value.parse(@schema, struct!(__MODULE__, attrs))
    end
  end

  def from_data(data), do: Value.invalid(data)
end

defmodule Jido.Seigyo.Client.CommandAttribution do
  @moduledoc "The durable member identity that submitted one Command."

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.CommandAttribution.schema(),
            ~w(session_id command_id member_id actor_id actor_kind display_name)a
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.CommandAttribution.schema(), data) do
      attrs = Map.new(@fields, fn {field, _} -> {field, data[Atom.to_string(field)]} end)
      Jido.Seigyo.Client.Value.parse(@schema, struct!(__MODULE__, attrs))
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)
end
