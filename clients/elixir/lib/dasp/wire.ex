defmodule DASP.Wire do
  @moduledoc """
  Validate structured CloudEvents against DASP draft-01.
  No remote schemas are loaded. Decoded keys remain strings.
  Profile validation is a separate application responsibility.
  """
  import DASP.Error, only: [fail: 2]
  @external_resource Path.expand("../../priv/envelope.schema.json", __DIR__)
  @schema @external_resource
          |> File.read!()
          |> Jason.decode!()
          |> JSV.build!(formats: true, atoms: false)

  @spec decode(binary()) :: {:ok, map()} | {:error, DASP.Error.t()}
  def decode(text), do: protect(fn -> decode!(text) end)
  @spec encode(map()) :: {:ok, binary()} | {:error, DASP.Error.t()}
  def encode(event), do: protect(fn -> encode!(event) end)

  @doc false
  def decode!(text) do
    event = DASP.JSON.decode!(text)

    case JSV.validate(event, @schema, cast: false) do
      {:ok, _} ->
        if event["type"] == "dasp.update.v1" and byte_size(text) > 65_536,
          do: fail(:invalid_event, "Update exceeds 65536 bytes.")

        limits!(event)
        event

      {:error, _} ->
        fail(:invalid_event, "Event does not match DASP draft-01.")
    end
  end

  @doc false
  def encode!(event) do
    text = DASP.JSON.encode!(event)
    decode!(text)
    text
  end

  @doc false
  def protect(fun) do
    {:ok, fun.()}
  rescue
    error in DASP.Error -> {:error, error}
  end

  defp limits!(%{"type" => type, "data" => data} = event) do
    if Map.has_key?(event, "subject") and Map.has_key?(data, "session_id") and
         event["subject"] != data["session_id"],
       do: fail(:invalid_event, "Subject differs from session_id.")

    strings!(data)

    if type == "dasp.update.v1" and byte_size(DASP.JSON.encode!(event)) > 65_536,
      do: fail(:invalid_event, "Update exceeds 65536 bytes.")

    if type == "dasp.updates.v1", do: Enum.each(data["events"], &limits!/1)

    case type do
      "dasp.command.v1" ->
        payload!(data["input"], 1)

      "dasp.view.v1" ->
        payload!(data["state"], 1)

      "dasp.progress.v1" ->
        payload!(data["payload"], 1)

      "dasp.update.v1" ->
        case data["kind"] do
          "application" -> payload!(data["payload"]["data"], 1)
          "command.outcome" -> payload!(data["payload"]["output"], 1)
          _ -> :ok
        end

      "dasp.outcome.v1" ->
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
