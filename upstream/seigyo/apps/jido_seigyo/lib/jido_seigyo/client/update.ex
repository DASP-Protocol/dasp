defmodule Jido.Seigyo.Client.Update do
  @moduledoc "One ordered durable Session update."

  alias Jido.Seigyo.Client.Value
  alias Jido.Seigyo.Client.SessionMember
  alias Jido.Seigyo.Schema

  # Only the projection names live here. Variants, field rules, and required
  # payload keys come from the canonical Update schema.
  @paths %{
    result_id: ~w(payload result_id),
    command_kind: ~w(payload kind),
    turn_state: ~w(payload state),
    reason: ~w(payload reason),
    mutation_id: ~w(payload mutation_id),
    config_revision: ~w(payload config_revision),
    previous_revision: ~w(payload previous_revision),
    effective_from: ~w(payload effective_from),
    disposition: ~w(payload disposition),
    previous_context_revision: ~w(payload previous_context_revision),
    context_revision: ~w(payload context_revision),
    source_from_sequence: ~w(payload source_from_sequence),
    source_to_sequence: ~w(payload source_to_sequence),
    preserved_turns: ~w(payload preserved_turns),
    estimated_tokens_before: ~w(payload estimated_tokens_before),
    estimated_tokens_after: ~w(payload estimated_tokens_after),
    member: ~w(payload member)
  }
  @fields Schema.fields(
            Jido.Seigyo.MembershipUpdate.schema(),
            ~w(session_id sequence event_type command_id result_id command_kind turn_state reason mutation_id config_revision previous_revision effective_from disposition previous_context_revision context_revision source_from_sequence source_to_sequence preserved_turns estimated_tokens_before estimated_tokens_after member)a,
            paths: @paths,
            projections: %{member: SessionMember.schema()}
          )
  @payload_fields Map.new(Jido.Seigyo.MembershipUpdate.schema().schemas, fn {event, schema} ->
                    keys = Schema.field(schema, "payload").fields |> Enum.map(&elem(&1, 0))
                    {event, keys}
                  end)
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)
          |> Zoi.refine({__MODULE__, :closed_variant, []})

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc "Returns the canonical Update data for replay comparison."
  def to_data(%__MODULE__{} = value) do
    keys = Map.fetch!(@payload_fields, value.event_type)

    payload =
      Map.new(@paths, fn {field, ["payload", name]} ->
        {name, value |> Map.fetch!(field) |> Value.to_data()}
      end)
      |> Map.take(keys)

    %{
      "version" => 1,
      "kind" => "event",
      "session_id" => value.session_id,
      "sequence" => value.sequence,
      "event_type" => value.event_type,
      "command_id" => value.command_id,
      "payload" => payload
    }
  end

  @doc false
  def closed_variant(%__MODULE__{} = value, _opts) do
    keys = Map.fetch!(@payload_fields, value.event_type)

    payload =
      Map.new(@paths, fn {field, ["payload", name]} ->
        {name, value |> Map.fetch!(field) |> Value.to_data()}
      end)

    unused_values = payload |> Map.drop(keys) |> Map.values()

    if Enum.all?(unused_values, &is_nil/1) do
      data = %{
        "version" => 1,
        "kind" => "event",
        "session_id" => value.session_id,
        "sequence" => value.sequence,
        "event_type" => value.event_type,
        "command_id" => value.command_id,
        "payload" => Map.take(payload, keys)
      }

      case Jido.Seigyo.MembershipUpdate.validate_data(data) do
        {:ok, _} -> :ok
        {:error, [error | _]} -> {:error, error}
      end
    else
      {:error,
       Zoi.Error.custom_error(issue: {"unused Update projection field", [field: "payload"]})}
    end
  end

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Value.parse(Jido.Seigyo.MembershipUpdate.schema(), data),
         {:ok, member} <- parse_member(data["payload"]["member"]) do
      attrs =
        Map.new(@fields, fn {field, _schema} ->
          path = Map.get(@paths, field, [Atom.to_string(field)])
          {field, if(field == :member, do: member, else: get_in(data, path))}
        end)

      Value.parse(@schema, struct!(__MODULE__, attrs))
    end
  end

  def from_data(data), do: Value.invalid(data)

  defp parse_member(nil), do: {:ok, nil}
  defp parse_member(data), do: SessionMember.from_data(data)
end
