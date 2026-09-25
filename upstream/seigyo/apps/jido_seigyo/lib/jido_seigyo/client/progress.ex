defmodule Jido.Seigyo.Client.Progress do
  @moduledoc "One bounded live replacement snapshot for an active Command."

  alias Jido.Seigyo.Client.Tool

  @field_names [
    :session_id,
    :command_id,
    :sequence,
    :iteration,
    :phase,
    :text,
    :truncated,
    :thinking,
    :thinking_truncated,
    :tools,
    :tools_truncated
  ]
  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.Progress.schema(),
            ~w(session_id command_id sequence iteration phase text truncated thinking thinking_truncated tools tools_truncated)a,
            projections: %{tools: Tool.schema()}
          )
  @schema Zoi.struct(
            __MODULE__,
            Map.merge(@fields, Jido.Seigyo.Client.Value.public_reasoning_fields()),
            unrecognized_keys: :error
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Progress.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, tools} <- map_tools(data["tools"]) do
      attrs =
        Map.new(@field_names, fn field -> {field, data[Atom.to_string(field)]} end)
        |> Map.put(:tools, tools)

      value = struct!(__MODULE__, attrs)
      Jido.Seigyo.Client.Value.parse(@schema, value)
    end
  end

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

  defp map_tools(tools), do: Jido.Seigyo.Client.Value.invalid(tools)
end
