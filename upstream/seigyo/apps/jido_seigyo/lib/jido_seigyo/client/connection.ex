defmodule Jido.Seigyo.Client.Connection do
  @moduledoc false

  use WebSockex

  @max_frame_bytes Jido.Seigyo.Contract.websocket_frame_bytes_limit()

  def start_link(url, owner) when is_binary(url) and is_pid(owner) do
    WebSockex.start_link(url, __MODULE__, %{owner: owner})
  end

  def send_frame(connection, frame),
    do: WebSockex.cast(connection, {:send, frame})

  def close(connection), do: WebSockex.cast(connection, :close)

  def websocket_url(base_url, token) when is_binary(base_url) and is_binary(token) do
    uri = URI.parse(base_url)

    with {:ok, scheme} <- websocket_scheme(uri.scheme),
         true <- is_binary(uri.host) and uri.host != "",
         true <- is_nil(uri.query),
         true <- is_nil(uri.fragment),
         true <- is_nil(uri.userinfo) do
      path = socket_path(uri.path)
      query = URI.encode_query(%{"token" => token, "vsn" => "2.0.0"})
      {:ok, URI.to_string(%{uri | scheme: scheme, path: path, query: query})}
    else
      _error -> {:error, :invalid_url}
    end
  end

  def websocket_url(_base_url, _token), do: {:error, :invalid_url}

  @impl true
  def handle_connect(_conn, %{owner: owner} = state) do
    send(owner, {:jido_seigyo_connected, self()})
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, encoded}, %{owner: owner} = state)
      when byte_size(encoded) <= @max_frame_bytes do
    message =
      case Jason.decode(encoded) do
        {:ok, frame} -> {:jido_seigyo_frame, self(), frame}
        {:error, reason} -> {:jido_seigyo_invalid_frame, self(), reason}
      end

    send(owner, message)
    {:ok, state}
  end

  def handle_frame({:text, _encoded}, %{owner: owner} = state) do
    send(owner, {:jido_seigyo_invalid_frame, self(), :frame_too_large})
    {:ok, state}
  end

  def handle_frame(_frame, %{owner: owner} = state) do
    send(owner, {:jido_seigyo_invalid_frame, self(), :unsupported_frame})
    {:ok, state}
  end

  @impl true
  def handle_cast({:send, frame}, %{owner: owner} = state) do
    encoded = Jason.encode!(frame)

    if byte_size(encoded) <= @max_frame_bytes do
      {:reply, {:text, encoded}, state}
    else
      send(owner, {:jido_seigyo_invalid_frame, self(), :frame_too_large})
      {:ok, state}
    end
  end

  def handle_cast(:close, state), do: {:close, state}

  @impl true
  def handle_disconnect(status, %{owner: owner} = state) do
    send(owner, {:jido_seigyo_disconnected, self(), status.reason})
    {:ok, state}
  end

  @impl true
  def terminate(reason, %{owner: owner}) do
    send(owner, {:jido_seigyo_terminated, self(), reason})
    :ok
  end

  defp websocket_scheme("ws"), do: {:ok, "ws"}
  defp websocket_scheme("wss"), do: {:ok, "wss"}
  defp websocket_scheme("http"), do: {:ok, "ws"}
  defp websocket_scheme("https"), do: {:ok, "wss"}
  defp websocket_scheme(_scheme), do: {:error, :invalid_scheme}

  defp socket_path(path) do
    path = String.trim_trailing(path || "", "/")

    if String.ends_with?(path, "/client/socket/websocket"),
      do: path,
      else: path <> "/client/socket/websocket"
  end
end
