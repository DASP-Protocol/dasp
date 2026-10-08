defmodule DASP.WebSocket do
  @moduledoc false
  # Mint state stays in the process which calls connect. This module starts no server.
  alias DASP.Error

  def connect(url, opts) do
    uri = URI.parse(url)
    secure = uri.scheme == "wss"

    transport =
      Keyword.merge(opts.tls_options,
        timeout: opts.connect_timeout,
        send_timeout: opts.write_timeout,
        send_timeout_close: true
      )

    transport =
      if secure,
        do: transport |> Keyword.put(:verify, :verify_peer) |> trust_roots(),
        else: transport

    with {:ok, conn} <-
           Mint.HTTP.connect(
             if(secure, do: :https, else: :http),
             uri.host,
             uri.port || if(secure, do: 443, else: 80),
             protocols: [:http1],
             mode: :passive,
             max_header_list_size: opts.max_handshake_bytes,
             transport_opts: transport
           ) do
      upgrade_request(conn, uri, secure, opts)
    else
      _ -> {:error, error(:transport, "WebSocket connection failed.")}
    end
  rescue
    _ -> {:error, error(:transport, "WebSocket connection failed.")}
  end

  defp upgrade_request(conn, uri, secure, opts) do
    path =
      if(uri.path in [nil, ""], do: "/", else: uri.path) <>
        if(uri.query, do: "?" <> uri.query, else: "")

    case Mint.WebSocket.upgrade(if(secure, do: :wss, else: :ws), conn, path, opts.headers) do
      {:ok, conn, ref} -> upgrade(conn, ref, opts, now() + opts.connect_timeout, 0, nil, [])
      {:error, conn, _} -> fail(conn, :setup, "WebSocket upgrade failed.")
    end
  rescue
    _ -> fail(conn, :setup, "WebSocket upgrade failed.")
  end

  defp trust_roots(opts) do
    if Keyword.has_key?(opts, :cacerts) or Keyword.has_key?(opts, :cacertfile),
      do: opts,
      else: Keyword.put(opts, :cacerts, :public_key.cacerts_get())
  end

  defp upgrade(conn, ref, opts, expires, bytes, status, headers) do
    remaining = expires - now()

    if remaining <= 0 do
      fail(conn, :timeout, "Upgrade deadline expired.")
    else
      result = Mint.WebSocket.recv(conn, 0, remaining)

      case result do
        {:ok, conn, replies} ->
          upgrade_result(conn, ref, opts, expires, bytes, status, headers, replies, "")

        {:error, conn, %Mint.HTTPError{reason: {:unexpected_data, rest}}, replies} ->
          upgrade_result(conn, ref, opts, expires, bytes, status, headers, replies, rest)

        {:error, conn, _, _} ->
          fail(conn, :transport, "WebSocket upgrade failed.")
      end
    end
  end

  defp upgrade_result(conn, ref, opts, expires, bytes, status, headers, replies, rest) do
    bytes = bytes + :erlang.external_size(replies)

    status =
      Enum.reduce(replies, status, fn
        {:status, ^ref, value}, _ -> value
        _, acc -> acc
      end)

    headers =
      Enum.reduce(replies, headers, fn
        {:headers, ^ref, value}, acc -> acc ++ value
        _, acc -> acc
      end)

    cond do
      bytes > opts.max_handshake_bytes or
          :erlang.external_size(conn) > opts.max_handshake_bytes + 16_384 ->
        fail(conn, :overflow, "Upgrade response exceeds its byte bound.")

      {:done, ref} in replies ->
        initial =
          Enum.reduce(replies, "", fn
            {:data, ^ref, data}, acc -> acc <> data
            _, acc -> acc
          end) <> rest

        with {:ok, conn, ws} <- Mint.WebSocket.new(conn, ref, status, headers, mode: :active) do
          {:ok, %{http: conn, ref: ref, ws: ws, headers: headers, initial: initial}}
        else
          {:error, conn, _} -> fail(conn, :setup, "Host refused the WebSocket upgrade.")
        end

      true ->
        upgrade(conn, ref, opts, expires, bytes, status, headers)
    end
  end

  # Setup runs with a finite deadline. The adapter must check authenticated exact selection.
  def setup(opts, info) do
    callback = fn ->
      try do
        opts.setup.(info)
      rescue
        _ -> :refused
      catch
        _, _ -> :refused
      end
    end

    case DASP.Callback.run(callback, opts.setup_timeout) do
      {:ok, :ok} -> :ok
      {:ok, _} -> {:error, error(:setup, "Authentication or exact contract selection failed.")}
      {:exit, _} -> {:error, error(:setup, "Setup adapter stopped.")}
      :timeout -> {:error, error(:timeout, "Setup deadline expired.")}
    end
  end

  def activate(socket) do
    case Mint.HTTP.set_mode(socket.http, :active) do
      {:ok, http} -> {:ok, %{socket | http: http}}
      _ -> {:error, error(:transport, "Cannot activate the WebSocket.")}
    end
  end

  def write(socket, frame) do
    with {:ok, ws, bytes} <- Mint.WebSocket.encode(socket.ws, frame),
         {:ok, http} <- Mint.WebSocket.stream_request_body(socket.http, socket.ref, bytes) do
      {:ok, %{socket | http: http, ws: ws}}
    else
      _ -> {:error, error(:transport, "WebSocket write failed. Admission can be unknown.")}
    end
  end

  def stream(socket, message) do
    case Mint.WebSocket.stream(socket.http, message) do
      {:ok, http, replies} ->
        {:ok, %{socket | http: http}, replies}

      {:error, _, _, _} ->
        {:error, error(:transport, "WebSocket connection lost. Admission can be unknown.")}

      :unknown ->
        :unknown
    end
  end

  def close(nil), do: :ok
  def close(socket), do: Mint.HTTP.close(socket.http)

  defp fail(conn, code, message) do
    Mint.HTTP.close(conn)
    {:error, error(code, message)}
  end

  defp error(code, message), do: %Error{code: code, message: message}
  defp now, do: System.monotonic_time(:millisecond)
end
