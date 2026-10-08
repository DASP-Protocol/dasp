defmodule DASP.Discovery.SchemaJSON do
  @moduledoc false

  import DASP.Error, only: [fail: 2]

  @default_max_nodes 100_000
  @max_depth 128
  @number :dasp_schema_json_number
  @container :dasp_schema_json_container

  def default_max_nodes, do: @default_max_nodes

  # Exact numeric text remains in the resource bytes. The validation tree only
  # needs a compact marker because discovery does not evaluate schema keywords.
  def decode(bytes, opts \\ [])

  def decode(bytes, opts) when is_binary(bytes) and is_list(opts) do
    case decode_with_count(bytes, opts) do
      {:ok, value, _nodes} -> {:ok, value}
      {:error, error} -> {:error, error}
    end
  end

  def decode(_, _), do: error(:invalid_schema, "Schema resource must be UTF-8 JSON bytes.")

  @doc false
  def decode_with_count(bytes, opts \\ [])

  def decode_with_count(bytes, opts) when is_binary(bytes) and is_list(opts) do
    case protect(fn -> decode!(bytes, opts) end) do
      {:ok, {value, nodes}} -> {:ok, value, nodes}
      {:error, error} -> {:error, error}
    end
  end

  def decode_with_count(_, _),
    do: error(:invalid_schema, "Schema resource must be UTF-8 JSON bytes.")

  defp decode!(bytes, opts) do
    if not String.valid?(bytes), do: fail(:invalid_schema, "Schema resource is not UTF-8 JSON.")

    max_nodes = Keyword.get(opts, :max_nodes, @default_max_nodes)

    if not is_integer(max_nodes) or max_nodes < 1,
      do: fail(:invalid_request, "The schema node limit must be a positive integer.")

    {value, _, rest} =
      :json.decode(bytes, {:root, 0, max_nodes}, %{
        array_start: &start_array/1,
        array_push: &push_array/2,
        array_finish: &finish_array/2,
        object_start: &start_object/1,
        object_push: &push_object/3,
        object_finish: &finish_object/2,
        integer: fn _token -> @number end,
        float: fn _token -> @number end,
        null: nil
      })

    if not Regex.match?(~r/\A[ \t\r\n]*\z/, rest),
      do: fail(:invalid_schema, "Schema resource has trailing JSON data.")

    {value, nodes} = unpack(value)
    ensure_node_budget!(nodes, max_nodes)
    {value, nodes}
  end

  defp start_array(acc) do
    depth = accumulator_depth(acc) + 1
    ensure_depth!(depth)
    {:array, [], 0, depth, accumulator_limit(acc)}
  end

  defp push_array(value, {:array, values, nodes, depth, max_nodes}) do
    {value, child_nodes} = unpack(value)
    nodes = nodes + child_nodes
    ensure_node_budget!(nodes + 1, max_nodes)
    {:array, [value | values], nodes, depth, max_nodes}
  end

  defp finish_array({:array, values, nodes, _depth, max_nodes}, old_acc) do
    nodes = nodes + 1
    ensure_node_budget!(nodes, max_nodes)
    {{@container, Enum.reverse(values), nodes}, old_acc}
  end

  defp start_object(acc) do
    depth = accumulator_depth(acc) + 1
    ensure_depth!(depth)
    {:object, %{}, 0, depth, accumulator_limit(acc)}
  end

  defp push_object(key, value, {:object, values, nodes, depth, max_nodes}) do
    if Map.has_key?(values, key),
      do: fail(:duplicate_json_key, "Schema resource contains a duplicate JSON object key.")

    {value, child_nodes} = unpack(value)
    nodes = nodes + child_nodes
    ensure_node_budget!(nodes + 1, max_nodes)
    {:object, Map.put(values, key, value), nodes, depth, max_nodes}
  end

  defp finish_object({:object, values, nodes, _depth, max_nodes}, old_acc) do
    nodes = nodes + 1
    ensure_node_budget!(nodes, max_nodes)
    {{@container, values, nodes}, old_acc}
  end

  defp unpack({@container, value, nodes}), do: {value, nodes}
  defp unpack(value), do: {value, 1}

  defp accumulator_depth({:root, depth, _max_nodes}), do: depth
  defp accumulator_depth({_kind, _values, _nodes, depth, _max_nodes}), do: depth

  defp accumulator_limit({:root, _depth, max_nodes}), do: max_nodes
  defp accumulator_limit({_kind, _values, _nodes, _depth, max_nodes}), do: max_nodes

  defp ensure_depth!(depth) when depth <= @max_depth, do: :ok

  defp ensure_depth!(_depth),
    do: fail(:invalid_schema, "Schema resource nesting exceeds the client limit.")

  defp ensure_node_budget!(nodes, max_nodes) when nodes <= max_nodes, do: :ok

  defp ensure_node_budget!(_nodes, _max_nodes),
    do: fail(:request_limit, "Schema resource exceeds the local node limit.")

  defp protect(fun) do
    {:ok, fun.()}
  rescue
    error in DASP.Error -> {:error, error}
    _ -> error(:invalid_schema, "Schema resource is not valid JSON.")
  end

  defp error(code, message), do: {:error, %DASP.Error{code: code, message: message}}
end
