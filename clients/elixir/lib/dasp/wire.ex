defmodule DASP.Wire do
  @moduledoc """
  Convert between DASP draft-01 JSON and Jido.Signal.

  The wire and Jido Signal V3 version is always "1.0".
  DASP extensions remain scalar values in signal.extensions. Data keys remain
  strings. Use this codec for DASP instead of the generic Jido serializer.
  No remote schemas are loaded. Profile validation is separate.
  """
  alias Jido.Signal
  alias DASP.Signal.Fields
  import DASP.Error, only: [fail: 2]
  @fields ~w(specversion id source type datacontenttype data subject time dataschema)a
  @wire_fields Enum.map(@fields, &Atom.to_string/1)
  @attribute Zoi.union([
               Zoi.string(),
               Zoi.boolean(),
               Zoi.integer() |> Zoi.gte(-2_147_483_648) |> Zoi.lte(2_147_483_647)
             ])
  @envelope Zoi.map(
              %{
                "specversion" => Zoi.literal("1.0"),
                "id" => Fields.nonempty_string(),
                "source" => Fields.uri(),
                "type" => Fields.nonempty_string(),
                "datacontenttype" => Zoi.literal("application/json"),
                "data" => Zoi.any(),
                "subject" => Fields.nonempty_string() |> Zoi.optional(),
                "dataschema" => Fields.uri() |> Zoi.optional(),
                "time" =>
                  Zoi.optional(
                    Zoi.string()
                    |> Zoi.refine({DASP.Signal.Validation, :timestamp, []})
                  ),
                "requestid" => Fields.identifier() |> Zoi.optional()
              },
              unrecognized_keys:
                {:preserve, {Zoi.string() |> Zoi.regex(~r/\A[a-z0-9]+\z/), @attribute}}
            )

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
    {event, _} = text |> DASP.JSON.decode!() |> validate!()

    if event["type"] == "dasp.v1.update" and byte_size(text) > 65_536,
      do: fail(:invalid_event, "Update exceeds 65536 bytes.")

    build_signal!(event)
  end

  defp validate!(event) do
    encoded = DASP.JSON.encode!(event)

    with {:ok, ^event} <- Zoi.parse(@envelope, event, coerce: false),
         module when not is_nil(module) <- DASP.Signal.module(event["type"]),
         true <-
           event["type"] in ~w(dasp.v1.update dasp.v1.progress dasp.v1.resync.required) or
             Map.has_key?(event, "requestid"),
         {:ok, data} <- Zoi.parse(module.schema(), event["data"], coerce: false),
         true <- data == event["data"] do
      limits!(event, byte_size(encoded))
      {event, encoded}
    else
      _ ->
        fail(:invalid_event, "Event does not match DASP draft-01.")
    end
  end

  @doc false
  def encode!(event) do
    {_, encoded} = event |> event_map!() |> validate!()
    encoded
  end

  @doc false
  def to_signal!(event), do: event |> to_map!() |> build_signal!()

  @doc false
  def to_map!(event) do
    {validated, _} = event |> event_map!() |> validate!()
    validated
  end

  defp event_map!(%Signal{} = signal) do
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

    Map.merge(core, signal.extensions)
  end

  defp event_map!(event), do: event

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

  defp limits!(%{"type" => type, "data" => data} = event, bytes) do
    if Enum.any?(Map.delete(event, "data"), fn {_, value} ->
         is_binary(value) and not context_string?(value)
       end),
       do: fail(:invalid_event, "Invalid CloudEvents context string.")

    if is_binary(event["dataschema"]) and String.contains?(event["dataschema"], "#"),
      do: fail(:invalid_event, "Schema URI must not contain a fragment.")

    if Map.has_key?(event, "subject") and Map.has_key?(data, "session_id") and
         event["subject"] != data["session_id"],
       do: fail(:invalid_event, "Subject differs from session_id.")

    if type == "dasp.v1.update" and bytes > 65_536,
      do: fail(:invalid_event, "Update exceeds 65536 bytes.")
  end

  defp context_string?(value) do
    Enum.all?(String.to_charlist(value), fn char ->
      char >= 0x20 and char not in 0x7F..0x9F and char not in 0xFDD0..0xFDEF and
        rem(char, 0x10000) not in [0xFFFE, 0xFFFF]
    end)
  end
end
