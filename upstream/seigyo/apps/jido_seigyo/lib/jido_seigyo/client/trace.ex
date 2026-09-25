defmodule Jido.Seigyo.Client.Trace do
  @moduledoc "A bounded execution trace returned to a client."

  alias Jido.Seigyo.Client.{Tool, ToolProfile, Value}

  @field_names [
    :session_id,
    :command_id,
    :model_id,
    :config_revision,
    :config_digest,
    :status,
    :failure_reason,
    :duration_ms,
    :model_calls,
    :input_tokens,
    :output_tokens,
    :truncated,
    :tools,
    :thinking,
    :thinking_truncated
  ]
  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.Trace.schema(),
            ~w(session_id command_id model_id config_revision config_digest tool_profile status failure_reason duration_ms model_calls input_tokens output_tokens truncated tools thinking thinking_truncated)a,
            projections: %{tools: Tool.schema(), tool_profile: ToolProfile.schema()}
          )
  @schema Zoi.struct(
            __MODULE__,
            Map.merge(@fields, Value.public_reasoning_fields()),
            unrecognized_keys: :error
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Trace.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, tools} <- map_tools(data["tools"]),
         {:ok, tool_profile} <- tool_profile(data["tool_profile"]) do
      attrs =
        Map.new(@field_names, fn field -> {field, data[Atom.to_string(field)]} end)
        |> Map.put(:tools, tools)
        |> Map.put(:tool_profile, tool_profile)

      value = struct!(__MODULE__, attrs)
      Value.parse(@schema, value)
    end
  end

  defp tool_profile(%{"id" => id, "version" => version, "digest" => digest} = data)
       when map_size(data) == 3 do
    Value.parse(ToolProfile.schema(), %ToolProfile{id: id, version: version, digest: digest})
  end

  defp tool_profile(value), do: Value.invalid(value)

  defp map_tools(tools) when is_list(tools) do
    Enum.reduce_while(tools, {:ok, []}, fn tool, {:ok, acc} ->
      case Tool.from_data(tool) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp map_tools(tools), do: Value.invalid(tools)
end
