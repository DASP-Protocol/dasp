defmodule Jido.Seigyo.Client.Wire do
  @moduledoc false

  alias Jido.Seigyo.Client.Error, as: ClientError
  alias Jido.Seigyo
  alias Jido.Seigyo.{Catalog, Error, Failure}

  @client_source "/jido/code/client"
  @server_source "/jido/code/server"
  @envelope_keys ~w(data id source specversion type)
  @max_signal_bytes Jido.Seigyo.Contract.signal_json_bytes_limit()

  def encode_request(signal, expected_module, features \\ [])

  def encode_request(%Jido.Signal{} = signal, expected_module, features) do
    with {:ok, valid} <- Seigyo.validate(signal, features: features),
         :ok <- expected_type(valid.type, expected_module.type()),
         :ok <- expected_source(valid.source, @client_source),
         :ok <- expected_direction(valid.type, :client_to_server, features),
         {:ok, encoded} <-
           Jido.Signal.serialize(valid, max_payload_bytes: @max_signal_bytes),
         {:ok, map} <- Jason.decode(encoded),
         :ok <- exact_keys(map, @envelope_keys) do
      {:ok, map}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, %ClientError{} = error} -> {:error, error}
      {:error, reason} -> {:error, ClientError.new(:protocol, reason)}
    end
  end

  def encode_request(_signal, _expected_module, _features),
    do: {:error, Error.new("invalid_field", "signal")}

  def decode_result(map, expected_module, features \\ []) do
    with {:ok, signal} <- decode_server_signal(map, features),
         :ok <- expected_type(signal.type, expected_module.type()) do
      {:ok, signal}
    end
  end

  def decode_failure(map) do
    with {:ok, signal} <- decode_server_signal(map, []),
         :ok <- expected_type(signal.type, Failure.type()),
         {:ok, error} <- Error.from_map(signal.data) do
      {:ok, error}
    else
      {:error, %ClientError{} = error} -> {:error, error}
      {:error, %Error{} = error} -> {:error, ClientError.new(:protocol, error)}
      {:error, reason} -> {:error, ClientError.new(:protocol, reason)}
    end
  end

  defp decode_server_signal(map, features) when is_map(map) do
    with :ok <- exact_keys(map, @envelope_keys),
         :ok <- valid_server_envelope(map),
         {:ok, encoded} <- Jason.encode(map),
         {:ok, signal} <-
           Jido.Signal.deserialize(encoded, max_payload_bytes: @max_signal_bytes),
         {:ok, valid} <- Seigyo.validate(signal, features: features),
         :ok <- expected_direction(valid.type, :server_to_client, features) do
      {:ok, valid}
    else
      {:error, %ClientError{} = error} -> {:error, error}
      {:error, reason} -> {:error, ClientError.new(:protocol, reason)}
    end
  end

  defp decode_server_signal(_map, _features),
    do: {:error, ClientError.new(:protocol, :invalid_signal_shape)}

  defp valid_server_envelope(%{
         "specversion" => "1.0",
         "id" => id,
         "source" => @server_source
       })
       when is_binary(id) do
    if id == String.downcase(id) and Jido.Signal.ID.valid?(id),
      do: :ok,
      else: {:error, ClientError.new(:protocol, :invalid_signal_id)}
  end

  defp valid_server_envelope(_map),
    do: {:error, ClientError.new(:protocol, :invalid_signal_envelope)}

  defp expected_type(type, type), do: :ok

  defp expected_type(_actual, _expected),
    do: {:error, ClientError.new(:protocol, :unexpected_signal_type)}

  defp expected_source(source, source), do: :ok

  defp expected_source(_actual, _expected),
    do: {:error, ClientError.new(:protocol, :unexpected_signal_source)}

  defp expected_direction(type, direction, features) do
    case Catalog.message(type, features) do
      {:ok, %{direction: ^direction}} -> :ok
      _ -> {:error, ClientError.new(:protocol, :unexpected_signal_role)}
    end
  end

  defp exact_keys(map, keys) do
    if Enum.sort(Map.keys(map)) == Enum.sort(keys),
      do: :ok,
      else: {:error, ClientError.new(:protocol, :unexpected_signal_fields)}
  end
end
