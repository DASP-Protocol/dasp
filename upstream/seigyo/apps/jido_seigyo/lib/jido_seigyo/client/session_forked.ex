defmodule Jido.Seigyo.Client.SessionForked do
  @moduledoc "The durable lineage returned for a forked Session or side chat."

  alias Jido.Seigyo.Client.{Session, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionForked.schema(),
              ~w(mutation_id session_id root_session_id parent_session_id fork_event_cursor relation workspace_id config_revision context_revision)a
            )
            |> Map.put(:session, Session.schema())
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, valid} <- validate_signal_data(data),
         {:ok, session} <-
           Session.from_data(
             valid
             |> Map.take(~w(version session_id workspace_id))
             |> Map.merge(%{"protocol_version" => 1, "protocol_profile" => "coding"})
           ) do
      Value.parse(@schema, %__MODULE__{
        mutation_id: valid["mutation_id"],
        session_id: valid["session_id"],
        session: session,
        root_session_id: valid["root_session_id"],
        parent_session_id: valid["parent_session_id"],
        fork_event_cursor: valid["fork_event_cursor"],
        relation: valid["relation"],
        workspace_id: valid["workspace_id"],
        config_revision: valid["config_revision"],
        context_revision: valid["context_revision"]
      })
    end
  end

  def from_data(data), do: Value.invalid(data)

  defp validate_signal_data(data) do
    case Jido.Seigyo.SessionForked.validate_data(data) do
      {:ok, valid} -> {:ok, valid}
      {:error, _issues} -> Value.invalid(data)
    end
  end
end
