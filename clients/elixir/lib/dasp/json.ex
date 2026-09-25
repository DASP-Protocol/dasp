defmodule DASP.JSON do
  @moduledoc false
  import DASP.Error, only: [fail: 2]
  @max 9_007_199_254_740_991

  def decode!(text) when is_binary(text) do
    if byte_size(text) > 1_048_576 or not String.valid?(text),
      do: fail(:invalid_json, "Invalid UTF-8 or message exceeds 1048576 bytes.")

    case Jason.decode(text, objects: :ordered_objects, floats: :decimals) do
      {:ok, value} ->
        decoded = convert(value, 0)
        raw_update_limits!(value, object_sizes(text), [])
        decoded

      {:error, _} ->
        fail(:invalid_json, "Invalid JSON.")
    end
  end

  def decode!(_), do: fail(:invalid_json, "Expected UTF-8 JSON bytes.")

  # Record original object byte lengths, including whitespace, in closing order.
  defp object_sizes(text) do
    {[], sizes} =
      Regex.scan(~r/"(?:[^"\\]|\\.)*"|[{}]/s, text, return: :index)
      |> Enum.reduce({[], []}, fn [{offset, length}], {stack, sizes} ->
        case binary_part(text, offset, length) do
          "{" ->
            {[offset | stack], sizes}

          "}" ->
            [start | rest] = stack
            {rest, [offset - start + 1 | sizes]}

          _ ->
            {stack, sizes}
        end
      end)

    Enum.reverse(sizes)
  end

  defp raw_update_limits!(%Jason.OrderedObject{values: pairs}, sizes, path) do
    [size | rest] =
      Enum.reduce(pairs, sizes, fn {key, child}, acc ->
        raw_update_limits!(child, acc, path ++ [key])
      end)

    if (path == [] or match?(["data", "events", _], path)) and
         List.keyfind(pairs, "type", 0) == {"type", "dasp.update.v1"} and size > 65_536,
       do: fail(:invalid_event, "Update exceeds 65536 bytes.")

    rest
  end

  defp raw_update_limits!(list, sizes, path) when is_list(list) do
    Enum.with_index(list)
    |> Enum.reduce(sizes, fn {child, index}, acc ->
      raw_update_limits!(child, acc, path ++ [index])
    end)
  end

  defp raw_update_limits!(_, sizes, _), do: sizes

  def encode!(value) do
    check!(value, 0)
    text = Jason.encode!(value)
    if byte_size(text) > 1_048_576, do: fail(:invalid_json, "Message exceeds 1048576 bytes.")
    text
  end

  defp convert(_, depth) when depth > 32, do: fail(:invalid_json, "JSON nesting limit exceeded.")

  defp convert(%Jason.OrderedObject{values: pairs}, depth) do
    if length(pairs) > 1024, do: fail(:invalid_json, "Object exceeds 1024 members.")

    Enum.reduce(pairs, %{}, fn {key, value}, acc ->
      if Map.has_key?(acc, key), do: fail(:invalid_json, "Duplicate JSON object key.")
      Map.put(acc, key, convert(value, depth + 1))
    end)
  end

  defp convert(%Decimal{coef: coef, exp: exp, sign: sign}, _depth) when is_integer(coef) do
    digits = Integer.to_string(coef)

    value =
      cond do
        coef == 0 ->
          0

        exp > 16 or exp < -byte_size(digits) ->
          fail(:invalid_json, "Number is outside the portable integer range.")

        exp < 0 ->
          divisor = Integer.pow(10, -exp)

          if rem(coef, divisor) != 0,
            do: fail(:invalid_json, "Fractions must use profile strings.")

          div(coef, divisor) * sign

        true ->
          coef * Integer.pow(10, exp) * sign
      end

    check!(value, 0)
    value
  end

  defp convert(list, depth) when is_list(list) do
    if length(list) > 1024, do: fail(:invalid_json, "Array exceeds 1024 items.")
    Enum.map(list, &convert(&1, depth + 1))
  end

  defp convert(value, depth) do
    check!(value, depth)
    value
  end

  def check!(_, depth) when depth > 32, do: fail(:invalid_json, "JSON nesting limit exceeded.")
  def check!(value, _) when is_integer(value) and value >= -@max and value <= @max, do: :ok
  def check!(value, _) when is_boolean(value) or is_nil(value), do: :ok

  def check!(value, _) when is_binary(value) do
    if not String.valid?(value), do: fail(:invalid_json, "Invalid UTF-8 string.")
    :ok
  end

  def check!(value, depth) when is_list(value) do
    if length(value) > 1024, do: fail(:invalid_json, "Array exceeds 1024 items.")
    Enum.each(value, &check!(&1, depth + 1))
  end

  def check!(value, depth) when is_map(value) and not is_struct(value) do
    if map_size(value) > 1024, do: fail(:invalid_json, "Object exceeds 1024 members.")

    Enum.each(value, fn {key, child} ->
      if not is_binary(key), do: fail(:invalid_json, "JSON object keys must be strings.")
      check!(key, depth + 1)
      check!(child, depth + 1)
    end)
  end

  def check!(_, _), do: fail(:invalid_json, "Value is not portable JSON.")
end
