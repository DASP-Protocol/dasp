defmodule DASP.Signal.Validation do
  @moduledoc false
  import DASP.Error, only: [fail: 2]

  def json_value(value, _) do
    DASP.JSON.check!(value, 0)
    :ok
  rescue
    _ -> {:error, "Expected portable JSON data."}
  end

  def data_limits(value, type, _) do
    data_limits!(type, value)
    :ok
  rescue
    _ -> {:error, "Data exceeds a DASP protocol limit."}
  end

  def uri(value, _), do: if(uri?(value), do: :ok, else: {:error, "Expected an absolute URI."})

  def timestamp(value, _),
    do: if(timestamp?(value), do: :ok, else: {:error, "Expected an RFC 3339 time."})

  def uri?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) ->
        Regex.match?(~r/\A[a-z][a-z0-9+.-]*:\S*\z/i, value) and
          not Regex.match?(~r/%(?![0-9a-f]{2})/i, value)

      _ ->
        false
    end
  end

  def uri?(_), do: false

  # RFC 3339 permits lowercase markers and leap seconds. Validate without
  # normalizing the saved wire spelling or relying on DateTime's 0..59 seconds.
  def timestamp?(value) do
    pattern =
      ~r/\A(\d{4}-\d{2}-\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?([Zz]|[+-]\d{2}:\d{2})\z/

    case Regex.run(pattern, value, capture: :all_but_first) do
      [date, hour, minute, second, zone] ->
        hour = String.to_integer(hour)
        minute = String.to_integer(minute)
        second = String.to_integer(second)

        with {:ok, date} <- Date.from_iso8601(date),
             {:ok, offset} <- offset(zone) do
          hour < 24 and minute < 60 and
            (second < 60 or
               (second == 60 and leap_second_position?(date, hour * 60 + minute - offset)))
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  # Check the UTC month boundary. Announced leap-second dates are not stored here.
  defp leap_second_position?(date, utc_minutes) do
    date = Date.add(date, Integer.floor_div(utc_minutes, 1440))
    Integer.mod(utc_minutes, 1440) == 1439 and date.day == Date.days_in_month(date)
  end

  defp offset(zone) when zone in ["Z", "z"], do: {:ok, 0}

  defp offset(<<sign, hours::binary-size(2), ":", minutes::binary-size(2)>>) do
    hours = String.to_integer(hours)
    minutes = String.to_integer(minutes)

    if hours < 24 and minutes < 60,
      do: {:ok, if(sign == ?-, do: -1, else: 1) * (hours * 60 + minutes)},
      else: :error
  end

  @doc false
  def data_limits!(type, data) do
    DASP.JSON.encode!(data)
    strings!(data)

    case type do
      "dasp.v1.command" ->
        payload!(data["input"], 1)

      "dasp.v1.view" ->
        payload!(data["state"], 1)

      "dasp.v1.progress" ->
        payload!(data["payload"], 1)

      "dasp.v1.update" ->
        case data["kind"] do
          "application" -> payload!(data["payload"]["data"], 1)
          "command.outcome" -> payload!(data["payload"]["output"], 1)
          _ -> :ok
        end

      "dasp.v1.outcome" ->
        payload!(get_in(data, ["outcome", "output"]), 1)

      _ ->
        :ok
    end
  end

  defp payload!(value, depth) when is_map(value) or is_list(value) do
    if depth > 16, do: fail(:invalid_event, "Profile payload exceeds 16 container levels.")
    values = if is_map(value), do: Map.values(value), else: value
    Enum.each(values, &payload!(&1, depth + 1))
  end

  defp payload!(_, _), do: :ok

  defp strings!(value) when is_binary(value) do
    if byte_size(value) > 65_536,
      do: fail(:invalid_event, "Application string exceeds 65536 bytes.")
  end

  defp strings!(value) when is_map(value),
    do:
      Enum.each(value, fn {key, child} ->
        strings!(key)
        strings!(child)
      end)

  defp strings!(value) when is_list(value), do: Enum.each(value, &strings!/1)
  defp strings!(_), do: :ok
end
