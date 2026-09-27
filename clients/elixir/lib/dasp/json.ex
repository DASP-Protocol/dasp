defmodule DASP.JSON do
  @moduledoc false
  import DASP.Error, only: [fail: 2]
  @max 9_007_199_254_740_991

  def decode!(text) when is_binary(text) do
    if byte_size(text) > 1_048_576 or not String.valid?(text),
      do: fail(:invalid_json, "Invalid UTF-8 or message exceeds 1048576 bytes.")

    {value, _, rest} =
      :json.decode(text, nil, %{
        object_finish: fn pairs, acc -> {{:object, Enum.reverse(pairs)}, acc} end,
        integer: &number!/1,
        float: &number!/1,
        null: nil
      })

    if not Regex.match?(~r/\A[ \t\r\n]*\z/, rest),
      do: fail(:invalid_json, "Trailing JSON data.")

    decoded = convert(value, 0)
    raw_update_limits!(value, object_sizes(text), [])
    decoded
  rescue
    error in DASP.Error -> reraise error, __STACKTRACE__
    _ -> fail(:invalid_json, "Invalid JSON.")
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

  defp raw_update_limits!({:object, pairs}, sizes, path) do
    [size | rest] =
      Enum.reduce(pairs, sizes, fn {key, child}, acc ->
        raw_update_limits!(child, acc, path ++ [key])
      end)

    if (path == [] or match?(["data", "events", _], path)) and
         List.keyfind(pairs, "type", 0) == {"type", "dasp.v1.update"} and size > 65_536,
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
    text = JSON.encode!(value)
    if byte_size(text) > 1_048_576, do: fail(:invalid_json, "Message exceeds 1048576 bytes.")
    text
  end

  defp convert(_, depth) when depth > 32, do: fail(:invalid_json, "JSON nesting limit exceeded.")

  defp convert({:object, pairs}, depth) do
    if length(pairs) > 1024, do: fail(:invalid_json, "Object exceeds 1024 members.")

    Enum.reduce(pairs, %{}, fn {key, value}, acc ->
      if Map.has_key?(acc, key), do: fail(:invalid_json, "Duplicate JSON object key.")
      Map.put(acc, key, convert(value, depth + 1))
    end)
  end

  defp convert(list, depth) when is_list(list) do
    if length(list) > 1024, do: fail(:invalid_json, "Array exceeds 1024 items.")
    Enum.map(list, &convert(&1, depth + 1))
  end

  defp convert(value, depth) do
    check!(value, depth)
    value
  end

  # Decode decimal and exponent syntax exactly, before any float conversion.
  # Bound exponent work by the input length and portable integer range.
  defp number!(token) do
    [mantissa | exponent] = String.split(token, ~r/[eE]/, parts: 2)
    sign = if String.starts_with?(mantissa, "-"), do: -1, else: 1
    [whole | fraction] = mantissa |> String.trim_leading("-") |> String.split(".", parts: 2)
    fraction = List.first(fraction) || ""
    digits = String.trim_leading(whole <> fraction, "0")

    if digits == "" do
      0
    else
      exponent = List.first(exponent) || "0"

      exponent_digits =
        exponent
        |> String.trim_leading("+")
        |> String.trim_leading("-")
        |> String.trim_leading("0")

      if byte_size(exponent_digits) > 7,
        do: fail(:invalid_json, "Number is outside the portable integer range.")

      power = String.to_integer(exponent) - byte_size(fraction)
      significant = String.trim_trailing(digits, "0")
      power = power + byte_size(digits) - byte_size(significant)

      if power < 0 or byte_size(significant) + power > 16,
        do: fail(:invalid_json, "Number is outside the portable integer range.")

      value = sign * String.to_integer(significant) * Integer.pow(10, power)
      check!(value, 0)
      value
    end
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
