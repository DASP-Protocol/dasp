defmodule DASP.Schema do
  @moduledoc false
  # This checker implements only the keywords in the pinned DASP schema.
  # It does not load application schemas or resolve external references.
  # Unknown keywords fail compilation when the pinned schema changes.
  @external_resource Path.expand("../../priv/envelope.schema.json", __DIR__)
  @schema @external_resource |> File.read!() |> JSON.decode!()
  @keywords ~w($schema $id title description $defs $ref type const enum oneOf anyOf properties required additionalProperties propertyNames items maxItems minimum maximum minLength pattern format)

  defp check_schema!(value) when is_map(value) do
    Enum.each(value, fn
      {key, children} when key in ["properties", "$defs"] ->
        Enum.each(children, fn {_, schema} -> check_schema!(schema) end)

      {key, child} when key in @keywords ->
        check_schema!(child)

      {key, _} ->
        raise "Unsupported DASP schema keyword: #{key}"
    end)
  end

  defp check_schema!(list) when is_list(list), do: Enum.each(list, &check_schema!/1)
  defp check_schema!(_), do: :ok

  def __after_compile__(_env, _bytecode), do: check_schema!(@schema)
  @after_compile __MODULE__

  def valid?(event), do: valid?(event, @schema)

  defp valid?(_value, true), do: true
  defp valid?(_value, false), do: false
  defp valid?(value, schema), do: Enum.all?(schema, &rule?(value, &1, schema))

  defp rule?(value, {"$ref", "#/$defs/" <> name}, _),
    do: valid?(value, Map.fetch!(@schema["$defs"], name))

  defp rule?(value, {"type", "object"}, _), do: is_map(value) and not is_struct(value)
  defp rule?(value, {"type", "array"}, _), do: is_list(value)
  defp rule?(value, {"type", "string"}, _), do: is_binary(value)
  defp rule?(value, {"type", "integer"}, _), do: is_integer(value)
  defp rule?(value, {"type", "boolean"}, _), do: is_boolean(value)
  defp rule?(value, {"type", "null"}, _), do: is_nil(value)
  defp rule?(value, {"const", expected}, _), do: value === expected
  defp rule?(value, {"enum", choices}, _), do: Enum.any?(choices, &(value === &1))
  defp rule?(value, {"oneOf", choices}, _), do: Enum.count(choices, &valid?(value, &1)) == 1
  defp rule?(value, {"anyOf", choices}, _), do: Enum.any?(choices, &valid?(value, &1))

  defp rule?(value, {"properties", properties}, _) when is_map(value),
    do:
      Enum.all?(properties, fn {key, schema} ->
        not Map.has_key?(value, key) or valid?(value[key], schema)
      end)

  defp rule?(value, {"required", keys}, _) when is_map(value),
    do: Enum.all?(keys, &Map.has_key?(value, &1))

  defp rule?(value, {"additionalProperties", additional}, schema) when is_map(value),
    do:
      value
      |> Map.drop(Map.keys(Map.get(schema, "properties", %{})))
      |> Enum.all?(fn {_, child} -> valid?(child, additional) end)

  defp rule?(value, {"propertyNames", schema}, _) when is_map(value),
    do: Enum.all?(Map.keys(value), &valid?(&1, schema))

  defp rule?(value, {"items", schema}, _) when is_list(value),
    do: Enum.all?(value, &valid?(&1, schema))

  defp rule?(value, {"maxItems", maximum}, _) when is_list(value), do: length(value) <= maximum
  defp rule?(value, {"minimum", minimum}, _) when is_number(value), do: value >= minimum
  defp rule?(value, {"maximum", maximum}, _) when is_number(value), do: value <= maximum

  defp rule?(value, {"minLength", minimum}, _) when is_binary(value),
    do: length(String.codepoints(value)) >= minimum

  defp rule?(value, {"pattern", pattern}, _) when is_binary(value),
    do: Regex.match?(Regex.compile!(pattern), value)

  defp rule?(value, {"format", "uri"}, _) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) ->
        Regex.match?(~r/\A[a-z][a-z0-9+.-]*:\S+\z/i, value) and
          not Regex.match?(~r/%(?![0-9a-f]{2})/i, value)

      _ ->
        false
    end
  end

  defp rule?(value, {"format", "date-time"}, _) when is_binary(value),
    do: timestamp?(value)

  defp rule?(_value, {key, _}, _) when key in @keywords, do: true

  # RFC 3339 permits lowercase markers and leap seconds. Validate without
  # normalizing the saved wire spelling or relying on DateTime's 0..59 seconds.
  defp timestamp?(value) do
    pattern =
      ~r/\A(\d{4}-\d{2}-\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?([Zz]|[+-]\d{2}:\d{2})\z/

    case Regex.run(pattern, value, capture: :all_but_first) do
      [date, hour, minute, second, zone] ->
        hour = String.to_integer(hour)
        minute = String.to_integer(minute)
        second = String.to_integer(second)

        with {:ok, _} <- Date.from_iso8601(date),
             {:ok, offset} <- offset(zone) do
          hour < 24 and minute < 60 and
            (second < 60 or
               (second == 60 and Integer.mod(hour * 60 + minute - offset, 1440) == 1439))
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp offset(zone) when zone in ["Z", "z"], do: {:ok, 0}

  defp offset(<<sign, hours::binary-size(2), ":", minutes::binary-size(2)>>) do
    hours = String.to_integer(hours)
    minutes = String.to_integer(minutes)

    if hours < 24 and minutes < 60,
      do: {:ok, if(sign == ?-, do: -1, else: 1) * (hours * 60 + minutes)},
      else: :error
  end
end
