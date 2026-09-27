defmodule DASP.Wire do
  @moduledoc """
  Convert between DASP draft-01 JSON and Jido.Signal.

  The wire and Jido Signal V3 version is always "1.0".
  DASP extensions remain scalar values in signal.extensions. Data keys remain
  strings. Use this codec for DASP instead of the generic Jido serializer.
  No remote schemas are loaded. Profile validation is separate.
  """
  alias Jido.Signal
  import DASP.Error, only: [fail: 2]
  @fields ~w(specversion id source type datacontenttype data subject time dataschema)a
  @wire_fields Enum.map(@fields, &Atom.to_string/1)

  @spec decode(binary()) :: {:ok, Signal.t()} | {:error, DASP.Error.t()}
  def decode(text), do: protect(fn -> decode!(text) end)
  @spec encode(Signal.t() | map()) :: {:ok, binary()} | {:error, DASP.Error.t()}
  def encode(event), do: protect(fn -> encode!(event) end)

  @doc "Validate an event and return a Jido.Signal without changing event identity."
  @spec to_signal(Signal.t() | map()) :: {:ok, Signal.t()} | {:error, DASP.Error.t()}
  def to_signal(event), do: protect(fn -> to_signal!(event) end)

  @doc "Return the validated DASP wire map for a signal or event map."
  @spec to_map(Signal.t() | map()) :: {:ok, map()} | {:error, DASP.Error.t()}
  def to_map(event), do: protect(fn -> to_map!(event) end)

  @doc false
  def decode!(text) do
    event = text |> DASP.JSON.decode!() |> validate!()

    if event["type"] == "dasp.v1.update" and byte_size(text) > 65_536,
      do: fail(:invalid_event, "Update exceeds 65536 bytes.")

    build_signal!(event)
  end

  defp validate!(event) do
    DASP.JSON.encode!(event)

    case DASP.Schema.valid?(event) do
      true ->
        limits!(event)
        event

      false ->
        fail(:invalid_event, "Event does not match DASP draft-01.")
    end
  end

  @doc false
  def encode!(event), do: event |> to_map!() |> DASP.JSON.encode!()

  @doc false
  def to_signal!(event), do: event |> to_map!() |> build_signal!()

  @doc false
  def to_map!(%Signal{} = signal) do
    if signal.specversion != "1.0" or signal.data_base64?,
      do: fail(:invalid_event, "Unsupported signal version or binary data.")

    if not is_map(signal.extensions) or is_struct(signal.extensions) or
         Enum.any?(@wire_fields, &Map.has_key?(signal.extensions, &1)),
       do: fail(:invalid_event, "Signal extensions must not replace core attributes.")

    core =
      Enum.reduce(@fields, %{}, fn key, acc ->
        case Map.fetch!(signal, key) do
          nil -> acc
          value -> Map.put(acc, Atom.to_string(key), value)
        end
      end)

    core |> Map.put("specversion", "1.0") |> Map.merge(signal.extensions) |> validate!()
  end

  def to_map!(event), do: validate!(event)

  defp build_signal!(event) do
    # DASP validates its own extension namespace. It permits names that the
    # Jido convenience API reserves, such as "extensions". Validate the core
    # through Jido, then retain the already-validated flat DASP attributes.
    extensions = Map.drop(event, @wire_fields)

    # Time is checked against RFC 3339 above. Jido's convenience timestamp
    # parser rejects valid leap seconds and lowercase markers.
    attrs = event |> Map.take(@wire_fields) |> Map.delete("time")

    case Signal.from_map(attrs) do
      {:ok, signal} -> %{signal | extensions: extensions, time: event["time"]}
      {:error, _} -> fail(:invalid_event, "Cannot represent this event as a Jido.Signal.")
    end
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

    if type == "dasp.v1.update" and byte_size(DASP.JSON.encode!(event)) > 65_536,
      do: fail(:invalid_event, "Update exceeds 65536 bytes.")

    if type == "dasp.v1.updates", do: Enum.each(data["events"], &limits!/1)

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
