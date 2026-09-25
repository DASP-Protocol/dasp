defmodule Jido.Seigyo.Client.ResultUsage do
  @moduledoc "Normalized model and delegation use for one Result."
  @fields ~w(measurement input_tokens output_tokens reasoning_tokens cache_read_tokens cache_write_tokens model_calls delegated_runs)a
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Result.usage_schema(),
              ~w(measurement input_tokens output_tokens reasoning_tokens cache_read_tokens cache_write_tokens model_calls delegated_runs)a
            )
          )
          |> Zoi.refine(
            {Jido.Seigyo.Client.Value, :canonical, [Jido.Seigyo.Result, :usage_schema, false]}
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
  def fields, do: @fields
end

defmodule Jido.Seigyo.Client.ResultReasoning do
  @moduledoc "The public reasoning policy for one Result."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Result.reasoning_schema(),
              ~w(visibility summary truncated)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.ResultBlock do
  @moduledoc "One normalized Result block."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Result.block_schema(),
              ~w(type text truncated attachment_id artifact_id name media_type workspace_id uri title)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.Result do
  @moduledoc "A normalized terminal coding Result."

  alias Jido.Seigyo.Client.{ResultBlock, ResultReasoning, ResultUsage, ToolProfile, Value}
  alias Jido.Seigyo.Error
  alias Jido.Seigyo.Result, as: SeigyoResult

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Result.schema(),
              ~w(result_id session_id command_id completion status config_revision config_digest tool_profile context_revision model_id blocks usage reasoning error)a,
              projections: %{
                tool_profile: ToolProfile.schema(),
                blocks: ResultBlock.schema(),
                usage: ResultUsage.schema(),
                reasoning: ResultReasoning.schema(),
                error: Zoi.struct(Error) |> Zoi.nullable()
              }
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Value.parse(SeigyoResult.schema(), data),
         {:ok, blocks} <- blocks(data["blocks"]),
         {:ok, tool_profile} <-
           fixed_struct(ToolProfile, ~w(id version digest)a, data["tool_profile"]),
         {:ok, usage} <- fixed_struct(ResultUsage, ResultUsage.fields(), data["usage"]),
         {:ok, reasoning} <-
           fixed_struct(ResultReasoning, ~w(visibility summary truncated)a, data["reasoning"]),
         {:ok, error} <- parse_error(data["error"]) do
      Value.parse(@schema, %__MODULE__{
        result_id: data["result_id"],
        session_id: data["session_id"],
        command_id: data["command_id"],
        completion: data["completion"],
        status: data["status"],
        config_revision: data["config_revision"],
        config_digest: data["config_digest"],
        tool_profile: tool_profile,
        context_revision: data["context_revision"],
        model_id: data["model_id"],
        blocks: blocks,
        usage: usage,
        reasoning: reasoning,
        error: error
      })
    end
  end

  def from_data(data), do: Value.invalid(data)

  defp blocks(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      attrs =
        ResultBlock.__struct__()
        |> Map.from_struct()
        |> Map.new(fn {key, _} -> {key, value[Atom.to_string(key)]} end)

      case Value.parse(ResultBlock.schema(), struct!(ResultBlock, attrs)) do
        {:ok, block} -> {:cont, {:ok, [block | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, blocks} -> {:ok, Enum.reverse(blocks)}
      error -> error
    end
  end

  defp blocks(value), do: Value.invalid(value)

  defp fixed_struct(module, fields, data) when is_map(data) do
    attrs = Map.new(fields, &{&1, data[Atom.to_string(&1)]})
    Value.parse(module.schema(), struct!(module, attrs))
  end

  defp fixed_struct(_module, _fields, value), do: Value.invalid(value)

  defp parse_error(nil), do: {:ok, nil}
  defp parse_error(value), do: Error.from_map(value)
end
