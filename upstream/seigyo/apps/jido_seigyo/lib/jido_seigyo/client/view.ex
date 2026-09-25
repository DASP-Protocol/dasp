defmodule Jido.Seigyo.Client.ExecutionSummary do
  @moduledoc "The safe execution placement in a Session view."

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.View.execution_schema(),
              ~w(target_id sandbox_id sandbox_profile isolation network status)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.View.execution_schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    attrs = Map.new(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
    Jido.Seigyo.Client.Value.parse(@schema, struct!(__MODULE__, attrs))
  rescue
    _ -> Jido.Seigyo.Client.Value.invalid(data)
  end
end

defmodule Jido.Seigyo.Client.View do
  @moduledoc "A bounded, typed Session view returned to a client."

  alias Jido.Seigyo.Client.{
    ActiveCommand,
    CommandOutcome,
    ExecutionSummary,
    Message,
    WorkspaceSummary
  }

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.View.schema(),
            ~w(session_id session_revision agent_revision event_cursor lifecycle active_command last_result last_result_command_id messages messages_truncated recent_outcomes execution workspace)a,
            paths: %{
              active_command: ~w(content active_command),
              last_result: ~w(content last_result),
              last_result_command_id: ~w(content last_result_command_id),
              messages: ~w(content messages),
              messages_truncated: ~w(content messages_truncated),
              recent_outcomes: ~w(content recent_outcomes),
              execution: ~w(content execution),
              workspace: ~w(content workspace)
            },
            projections: %{
              active_command: ActiveCommand.schema(),
              messages: Message.schema(),
              recent_outcomes: CommandOutcome.schema(),
              execution: ExecutionSummary.schema(),
              workspace: WorkspaceSummary.schema()
            }
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)
          |> Zoi.refine({__MODULE__, :coherent_result, []})

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def coherent_result(%__MODULE__{} = view, opts) do
    content_keys = Jido.Seigyo.View.content_schema().fields |> Enum.map(&elem(&1, 0))
    flat = Jido.Seigyo.Client.Value.to_data(view)
    data = flat |> Map.drop(content_keys) |> Map.put("content", Map.take(flat, content_keys))
    Jido.Seigyo.Client.Value.canonical(data, Jido.Seigyo.View, :schema, true, opts)
  end

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.View.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(%{"content" => content} = data) do
    with {:ok, active_command} <- active_command(content["active_command"]),
         {:ok, messages} <- map_values(content["messages"], &Message.from_data/1),
         {:ok, recent_outcomes} <-
           map_values(content["recent_outcomes"], &CommandOutcome.from_data/1),
         {:ok, execution} <- ExecutionSummary.from_data(content["execution"]),
         {:ok, workspace} <- WorkspaceSummary.from_data(content["workspace"]) do
      value = %__MODULE__{
        session_id: data["session_id"],
        session_revision: data["session_revision"],
        agent_revision: data["agent_revision"],
        event_cursor: data["event_cursor"],
        lifecycle: data["lifecycle"],
        active_command: active_command,
        last_result: content["last_result"],
        last_result_command_id: content["last_result_command_id"],
        messages: messages,
        messages_truncated: content["messages_truncated"],
        recent_outcomes: recent_outcomes,
        execution: execution,
        workspace: workspace
      }

      Jido.Seigyo.Client.Value.parse(@schema, value)
    end
  end

  defp active_command(nil), do: {:ok, nil}
  defp active_command(data), do: ActiveCommand.from_data(data)

  defp map_values(values, parser) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, parsed} ->
      case parser.(value) do
        {:ok, item} -> {:cont, {:ok, [item | parsed]}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end
  end

  defp map_values(value, _parser), do: Jido.Seigyo.Client.Value.invalid(value)
end
