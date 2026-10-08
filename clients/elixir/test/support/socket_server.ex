defmodule DASP.TestSocketServer do
  @moduledoc false
  import Bitwise
  @host "urn:example:host:one"
  def start(opts \\ []) do
    parent = self()
    mod = if opts[:tls], do: :ssl, else: :gen_tcp
    tcp = [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}]
    tls = if opts[:tls], do: [certfile: opts[:certfile], keyfile: opts[:keyfile]], else: []
    {:ok, listen} = mod.listen(0, tcp ++ tls)
    {:ok, {_, port}} = if mod == :ssl, do: :ssl.sockname(listen), else: :inet.sockname(listen)

    pid =
      spawn(fn ->
        socket =
          case accept(mod, listen) do
            {:ok, socket} -> socket
            {:error, _} -> exit(:normal)
          end

        headers = headers(mod, socket, "")
        send(parent, {:upgrade, self(), headers})
        if opts[:upgrade_delay], do: Process.sleep(opts[:upgrade_delay])

        key =
          Regex.run(~r/sec-websocket-key:\s*([^\r\n]+)/i, headers) |> Enum.at(1) |> String.trim()

        accept =
          :crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> Base.encode64()

        response =
          "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\nX-Test-Selection: draft-01\r\n\r\n"

        mod.send(socket, response <> Keyword.get(opts, :initial, ""))
        set_active(mod, socket)
        loop(%{socket: socket, mod: mod, owner: parent, buffer: "", opts: opts})
      end)

    scheme = if mod == :ssl, do: "wss", else: "ws"
    hostname = if mod == :ssl, do: "localhost", else: "127.0.0.1"
    {pid, "#{scheme}://#{hostname}:#{port}/agent", listen, mod}
  end

  def stop({pid, _, listen, mod}) do
    send(pid, :stop)
    mod.close(listen)
  end

  def send_event(pid, event), do: send(pid, {:send, 1, JSON.encode!(event), true})

  def send_frame(pid, opcode, payload, final \\ true),
    do: send(pid, {:send, opcode, payload, final})

  def send_raw(pid, data), do: send(pid, {:raw, data})
  def drop(pid), do: send(pid, :stop)

  defp accept(:gen_tcp, listen), do: :gen_tcp.accept(listen, 5_000)

  defp accept(:ssl, listen) do
    with {:ok, socket} <- :ssl.transport_accept(listen, 5_000), do: :ssl.handshake(socket, 5_000)
  end

  defp headers(mod, socket, bytes) do
    if String.contains?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, data} = mod.recv(socket, 0, 5_000)
      headers(mod, socket, bytes <> data)
    end
  end

  defp loop(s) do
    socket = s.socket

    receive do
      {tag, ^socket, data} when tag in [:tcp, :ssl] ->
        {frames, buffer} = parse(s.buffer <> data, [])

        Enum.each(frames, fn {op, payload} ->
          send(s.owner, {:frame, self(), op, payload})

          cond do
            op == 8 and s.opts[:ignore_close] != true ->
              s.mod.send(socket, frame(8, <<1000::16>>, true))

            op == 1 and s.opts[:auto_open] != false ->
              request = JSON.decode!(payload)

              if request["type"] == "dasp.v1.session.open" do
                event = %{
                  "specversion" => "1.0",
                  "id" => "opened-#{System.unique_integer([:positive])}",
                  "source" => @host,
                  "type" => "dasp.v1.session.opened",
                  "datacontenttype" => "application/json",
                  "requestid" => request["requestid"],
                  "data" => Map.put(request["data"], "cursor", Keyword.get(s.opts, :head, 0))
                }

                s.mod.send(socket, frame(1, JSON.encode!(event), true))
              end

            true ->
              :ok
          end
        end)

        set_active(s.mod, socket)
        loop(%{s | buffer: buffer})

      {:send, op, payload, final} ->
        s.mod.send(socket, frame(op, payload, final))
        loop(s)

      {:raw, data} ->
        s.mod.send(socket, data)
        loop(s)

      :stop ->
        s.mod.close(socket)

      {tag, ^socket} when tag in [:tcp_closed, :ssl_closed] ->
        send(s.owner, {:server_closed, self()})

      {tag, ^socket, _} when tag in [:tcp_error, :ssl_error] ->
        send(s.owner, {:server_closed, self()})
    end
  end

  defp set_active(:gen_tcp, socket), do: :inet.setopts(socket, active: :once)
  defp set_active(:ssl, socket), do: :ssl.setopts(socket, active: :once)

  def frame(op, payload, final) do
    len = byte_size(payload)
    head = <<if(final, do: 128, else: 0) + op>>

    length =
      cond do
        len < 126 -> <<len>>
        len < 65536 -> <<126, len::16>>
        true -> <<127, len::64>>
      end

    head <> length <> payload
  end

  defp parse(bytes, acc) when byte_size(bytes) < 2, do: {Enum.reverse(acc), bytes}

  defp parse(<<first, masklen, rest::binary>> = bytes, acc) do
    masked = (masklen &&& 128) == 128
    len = masklen &&& 127

    parsed =
      cond do
        len < 126 ->
          {len, rest}

        len == 126 and byte_size(rest) >= 2 ->
          <<n::16, r::binary>> = rest
          {n, r}

        len == 127 and byte_size(rest) >= 8 ->
          <<n::64, r::binary>> = rest
          {n, r}

        true ->
          nil
      end

    if parsed == nil do
      {Enum.reverse(acc), bytes}
    else
      {len, rest} = parsed

      if not masked or byte_size(rest) < len + 4 do
        {Enum.reverse(acc), bytes}
      else
        <<mask::binary-size(4), data::binary-size(^len), tail::binary>> = rest
        mask = :binary.bin_to_list(mask)

        payload =
          for {b, i} <- Enum.with_index(:binary.bin_to_list(data)),
              into: <<>>,
              do: <<bxor(b, Enum.at(mask, rem(i, 4)))>>

        parse(tail, [{first &&& 15, payload} | acc])
      end
    end
  end
end
