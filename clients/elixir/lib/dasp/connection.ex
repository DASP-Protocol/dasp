defmodule DASP.Connection do
  @moduledoc """
  Functional DASP connection, owned by the calling process.

  Serialize all calls in that process. Feed its socket messages to stream/2.
  Feed a local timer to tick/1, using next_timeout/1 to set its deadline.
  Both functions return events; unrelated process messages return :unknown.
  No request retry, reconnect, or applied cursor change occurs here.
  """
  alias DASP.{Client, Error, WebSocket, Wire}
  import DASP.Error, only: [fail: 2]

  @push ~w(dasp.v1.update dasp.v1.progress dasp.v1.resync.required)
  @timeout Zoi.integer() |> Zoi.gte(1) |> Zoi.lte(2_147_483_647)
  @callback_type Zoi.function() |> Zoi.refine({__MODULE__, :unary, []})
  @options Zoi.map(
             %{
               source: DASP.Signal.Fields.uri(),
               host_source: DASP.Signal.Fields.uri(),
               setup: @callback_type,
               validate_profile: @callback_type,
               timeout: @timeout,
               connect_timeout: @timeout,
               setup_timeout: @timeout,
               write_timeout: @timeout,
               close_timeout: @timeout,
               max_message_bytes: @timeout |> Zoi.lte(1_048_576),
               max_buffer_bytes: @timeout,
               max_handshake_bytes: @timeout,
               max_pending_requests: @timeout,
               max_tracked_requests: @timeout,
               max_sessions: @timeout,
               max_frames_per_read: @timeout,
               headers: Zoi.array(Zoi.tuple({Zoi.string(), Zoi.string()})),
               tls_options: Zoi.any() |> Zoi.refine({__MODULE__, :tls_options, []}),
               allow_insecure: Zoi.boolean()
             },
             unrecognized_keys: :error
           )
  defstruct [
    :socket,
    :options,
    :owner,
    :failure,
    :close_at,
    :drain_at,
    phase: :open,
    pending: %{},
    seen: MapSet.new(),
    cancelled: %{},
    sessions: %{}
  ]

  def connect(url, opts) do
    with {:ok, options} <- options(url, opts),
         {:ok, socket} <- WebSocket.connect(url, options) do
      info = %{
        url: url,
        source: options.source,
        host_source: options.host_source,
        status: 101,
        headers: socket.headers
      }

      with :ok <- WebSocket.setup(options, info), {:ok, socket} <- WebSocket.activate(socket) do
        conn = %__MODULE__{socket: socket, options: options, owner: self()}

        case bytes(conn, socket.initial) do
          {:ok, next, []} ->
            {:ok, next}

          {:ok, next, _} ->
            WebSocket.close(next.socket)
            {:error, next.failure || error(:setup, "Core traffic arrived before session open.")}
        end
      else
        {:error, e} ->
          WebSocket.close(socket)
          {:error, e}
      end
    end
  end

  defp options(url, opts) do
    defaults = [
      timeout: 10_000,
      connect_timeout: 5_000,
      setup_timeout: 5_000,
      write_timeout: 2_000,
      close_timeout: 1_000,
      max_message_bytes: 1_048_576,
      max_buffer_bytes: 2_097_152,
      max_handshake_bytes: 65_536,
      max_pending_requests: 100,
      max_tracked_requests: 4096,
      max_sessions: 100,
      max_frames_per_read: 1024,
      headers: [],
      tls_options: [],
      allow_insecure: false
    ]

    with true <- is_list(opts) and Keyword.keyword?(opts),
         {:ok, options} <-
           Zoi.parse(@options, Map.new(Keyword.merge(defaults, opts)), coerce: false),
         {:ok, %URI{scheme: scheme, host: host, userinfo: nil, fragment: nil}} <- URI.new(url),
         true <- scheme in ["ws", "wss"] and is_binary(host) and host != "",
         true <- options.allow_insecure or scheme == "wss" do
      {:ok, options}
    else
      _ ->
        {:error,
         error(
           :configuration,
           "Supply a WebSocket URL, verified TLS, sources, setup adapter, and profile validator."
         )}
    end
  rescue
    _ -> {:error, error(:configuration, "Invalid connection options.")}
  end

  @doc "Send a fresh attempt. Errors return the connection state as the second item."
  def request(conn, signal, opts \\ []) do
    case protect(fn -> prepare!(conn, signal, opts) end) do
      {:ok, {prepared, wire, session, timeout, replay_head}} ->
        case WebSocket.write(conn.socket, {:text, wire}) do
          {:ok, socket} ->
            local_ref = make_ref()
            id = prepared.extensions["requestid"]

            pending = %{
              ref: local_ref,
              signal: prepared,
              expires: now() + timeout,
              replay_head: replay_head
            }

            next = %{
              conn
              | socket: socket,
                pending: Map.put(conn.pending, id, pending),
                seen: MapSet.put(conn.seen, id),
                sessions: session
            }

            {:ok, next, local_ref}

          {:error, e} ->
            WebSocket.close(conn.socket)
            # tick/1 emits terminal results for the other accepted requests.
            {:error, %{conn | phase: :failed, failure: e}, e}
        end

      {:error, e} ->
        {:error, conn, e}
    end
  end

  defp prepare!(conn, %Jido.Signal{} = signal, opts) do
    owner!(conn)

    if conn.phase != :open or conn.drain_at,
      do: fail(:closed, "The connection is closed or draining.")

    if is_nil(DASP.Signal.reply_type(signal.type)),
      do: fail(:invalid_event, "Only core request types can be sent.")

    if signal.source != conn.options.source,
      do: fail(:correlation, "Request source differs from the selected client.")

    if not is_list(opts) or not Keyword.keyword?(opts) or
         Keyword.keys(opts) -- [:timeout, :replay_head] != [],
       do: fail(:configuration, "Request options contain an unknown key.")

    timeout = Keyword.get(opts, :timeout, conn.options.timeout)
    timeout!(timeout)
    replay_head = Keyword.get(opts, :replay_head)

    if replay_head != nil and
         (signal.type != "dasp.v1.updates.read" or
            not is_integer(replay_head) or replay_head < 0 or
            replay_head > DASP.JSON.max_integer()),
       do:
         fail(
           :configuration,
           "replay_head must be a captured nonnegative head for an updates.read request."
         )

    if map_size(conn.pending) >= conn.options.max_pending_requests,
      do: fail(:overflow, "Pending request bound reached.")

    if MapSet.size(conn.seen) >= conn.options.max_tracked_requests,
      do: fail(:overflow, "Attempt tracking bound reached. Drain and reconnect.")

    # Change only attempt metadata. Keep the caller's signal and semantic data intact.
    event = %{
      signal
      | id: Jido.Signal.ID.generate!(),
        extensions: Map.put(signal.extensions, "requestid", Jido.Signal.ID.generate!())
    }

    wire = Wire.encode!(event)

    if byte_size(wire) > conn.options.max_message_bytes,
      do: fail(:overflow, "Core message exceeds its selected byte bound.")

    profile!(conn, event)
    sessions = request_session!(conn, event)

    if replay_head != nil and
         (event.data["after"] >= replay_head or
            event.data["limit"] > replay_head - event.data["after"]),
       do: fail(:replay, "A recovery request must stay within its captured head.")

    {event, wire, sessions, timeout, replay_head}
  end

  defp prepare!(_, _, _), do: fail(:invalid_event, "Supply an ordinary Jido.Signal request.")

  defp request_session!(conn, event) do
    id = event.data["session_id"]
    session = conn.sessions[id]

    if event.type == "dasp.v1.session.open" do
      tuple = event.data

      if session && session.tuple != tuple,
        do: fail(:correlation, "Session actor and profile are immutable.")

      if Enum.any?(conn.pending, fn {_, p} ->
           p.signal.type == event.type and p.signal.data["session_id"] == id
         end),
         do: fail(:correlation, "Another session open is pending.")

      if is_nil(session) and map_size(conn.sessions) >= conn.options.max_sessions,
        do: fail(:overflow, "Session bound reached.")

      Map.put(conn.sessions, id, session || %{tuple: tuple, active: false, next_push: nil})
    else
      if is_nil(session) or not session.active,
        do: fail(:session, "Open the session before sending this request.")

      conn.sessions
    end
  end

  @doc "Decode socket input. Events are reply results, unsolicited signals, or connection errors."
  def stream(conn, message) do
    owner!(conn)

    cond do
      conn.phase == :failed ->
        close(conn, conn.failure)

      conn.phase == :closed ->
        :unknown

      true ->
        case WebSocket.stream(conn.socket, message) do
          :unknown ->
            :unknown

          {:error, e} ->
            close(conn, e)

          {:ok, socket, responses} ->
            {:ok, conn, due} = tick(%{conn | socket: socket})

            {events, conn} =
              Enum.flat_map_reduce(responses, conn, fn
                {:data, ref, data}, %{socket: %{ref: ref}} = c ->
                  {:ok, next, events} = bytes(c, data)
                  {events, next}

                _, c ->
                  {[], c}
              end)

            {:ok, conn, due ++ events}
        end
    end
  end

  defp bytes(conn, ""), do: {:ok, conn, []}
  defp bytes(%{phase: :closed} = conn, _), do: {:ok, conn, []}

  defp bytes(conn, data) do
    if byte_size(data) + :erlang.external_size(conn.socket.ws) > conn.options.max_buffer_bytes do
      close(conn, error(:overflow, "WebSocket assembly exceeds its byte bound."))
    else
      case Mint.WebSocket.decode(conn.socket.ws, data) do
        {:ok, ws, frames} ->
          conn = %{conn | socket: %{conn.socket | ws: ws}}

          if :erlang.external_size(ws) > conn.options.max_buffer_bytes or
               length(frames) > conn.options.max_frames_per_read do
            close(conn, error(:overflow, "WebSocket assembly exceeds its byte bound."))
          else
            {events, conn} =
              Enum.flat_map_reduce(frames, conn, fn frame, c ->
                {:ok, next, events} = frame(c, frame)
                {events, next}
              end)

            {:ok, conn, events}
          end

        {:error, _, _} ->
          close(conn, error(:transport, "Invalid WebSocket frame."))
      end
    end
  end

  defp frame(%{phase: :closed} = conn, _), do: {:ok, conn, []}

  defp frame(conn, {:ping, data}) do
    case WebSocket.write(conn.socket, {:pong, data}) do
      {:ok, socket} -> {:ok, %{conn | socket: socket}, []}
      {:error, e} -> close(conn, e)
    end
  end

  defp frame(conn, {:pong, _}), do: {:ok, conn, []}

  defp frame(conn, {:close, _, _}) do
    _ = WebSocket.write(conn.socket, {:close, 1000, ""})
    close(conn, conn.failure || error(:transport, "Host closed the WebSocket."))
  end

  defp frame(%{phase: :closing} = conn, _), do: {:ok, conn, []}

  defp frame(conn, {:text, wire}) do
    case protect(fn ->
           if byte_size(wire) > conn.options.max_message_bytes,
             do: fail(:overflow, "Core message exceeds its selected byte bound.")

           event = Wire.decode!(wire)

           if event.source != conn.options.host_source,
             do: fail(:correlation, "Unexpected reply or signal source.")

           profile!(conn, event)
           receive_event!(conn, event)
         end) do
      {:ok, {next, events}} -> {:ok, next, events}
      {:error, e} -> close(conn, e)
    end
  end

  defp frame(conn, _),
    do: close(conn, error(:invalid_event, "This binding requires JSON text messages."))

  defp receive_event!(conn, %{type: type} = event) when type in @push do
    id = event.data["session_id"]
    session = conn.sessions[id]

    if is_nil(session) or not session.active,
      do: fail(:session, "Push has no active session attachment.")

    session =
      case type do
        "dasp.v1.update" ->
          if event.data["sequence"] != session.next_push,
            do: fail(:gap, "Live push sequence has a gap or repeat.")

          %{session | next_push: session.next_push + 1}

        "dasp.v1.resync.required" ->
          %{session | active: false, next_push: nil}

        _ ->
          session
      end

    next = %{conn | sessions: Map.put(conn.sessions, id, session)}

    {next, cancelled} =
      if type == "dasp.v1.resync.required" do
        Enum.reduce(conn.pending, {next, []}, fn {rid, p}, {c, events} ->
          if p.replay_head != nil and p.signal.data["session_id"] == id do
            e = error(:resync, "The host ended this live attachment. Reopen before recovery.")

            {%{
               c
               | pending: Map.delete(c.pending, rid),
                 cancelled: Map.put(c.cancelled, rid, context(p.signal))
             }, events ++ [{:reply, p.ref, {:error, e}}]}
          else
            {c, events}
          end
        end)
      else
        {next, []}
      end

    {next, cancelled ++ [{:signal, event}]}
  end

  defp receive_event!(conn, event) do
    id = event.extensions["requestid"]

    case conn.pending[id] do
      nil ->
        case conn.cancelled[id] do
          nil ->
            fail(:correlation, "Reply has no pending request.")

          request ->
            reply!(conn, request, event)
            {conn, []}
        end

      p ->
        reply!(conn, p.signal, event)

        if p.replay_head != nil and event.type == "dasp.v1.updates" and
             event.data["head"] < p.replay_head,
           do: fail(:continuity, "Replay lost its captured history head.")

        sessions =
          if event.type == "dasp.v1.session.opened" do
            sid = event.data["session_id"]
            s = conn.sessions[sid]

            if s.active,
              do: conn.sessions,
              else:
                Map.put(conn.sessions, sid, %{
                  s
                  | active: true,
                    next_push: event.data["cursor"] + 1
                })
          else
            conn.sessions
          end

        {%{conn | pending: Map.delete(conn.pending, id), sessions: sessions},
         [{:reply, p.ref, {:ok, event}}]}
    end
  end

  defp reply!(_, _, %{type: "dasp.v1.failure"}), do: :ok

  defp reply!(conn, request, event) do
    q = request.data
    d = event.data

    if event.type != DASP.Signal.reply_type(request.type) or d["session_id"] != q["session_id"] or
         (Map.has_key?(q, "command_id") and d["command_id"] != q["command_id"]),
       do: fail(:correlation, "Reply differs from the request context.")

    session = conn.sessions[q["session_id"]]

    if Map.has_key?(d, "actor_id") and
         Map.take(d, ~w(session_id actor_id profile)) != session.tuple,
       do: fail(:correlation, "Reply changed the session actor or profile.")

    if event.type == "dasp.v1.updates" do
      Client.page!(event, q["after"], q["limit"])

      Enum.each(d["events"], fn raw ->
        update = Wire.to_signal!(raw)

        if update.source != conn.options.host_source,
          do: fail(:correlation, "Replay producer differs from the selected host.")

        profile!(conn, update)
      end)
    end
  end

  @doc "Run due request and lifecycle deadlines. No process timer is started by the engine."
  def tick(conn) do
    owner!(conn)
    current = now()

    cond do
      conn.phase == :closed ->
        {:ok, conn, []}

      conn.phase == :failed ->
        close(conn, conn.failure)

      conn.phase == :closing and current >= conn.close_at ->
        close(conn, conn.failure)

      conn.drain_at && current >= conn.drain_at ->
        close(conn, error(:drain_timeout, "Drain deadline expired. Admission can be unknown."))

      true ->
        {conn, events} =
          Enum.reduce(conn.pending, {conn, []}, fn {id, p}, {c, events} ->
            if Map.has_key?(c.pending, id) and current >= p.expires do
              e = error(:timeout, "Reply deadline expired. Command admission can be unknown.")

              if p.signal.type == "dasp.v1.session.open" do
                {:ok, next, more} = close(c, e)
                {next, events ++ more}
              else
                next = %{
                  c
                  | pending: Map.delete(c.pending, id),
                    cancelled: Map.put(c.cancelled, id, context(p.signal))
                }

                {next, events ++ [{:reply, p.ref, {:error, e}}]}
              end
            else
              {c, events}
            end
          end)

        if (conn.phase == :open and conn.drain_at) && map_size(conn.pending) == 0 do
          {:ok, next, more} = closing(conn, error(:drained, "The connection drained."))
          {:ok, next, events ++ more}
        else
          {:ok, conn, events}
        end
    end
  end

  @doc "Return milliseconds until the next local deadline, or :infinity."
  def next_timeout(conn) do
    times =
      Enum.map(conn.pending, fn {_, p} -> p.expires end) ++
        Enum.filter([conn.close_at, conn.drain_at], &is_integer/1)

    cond do
      conn.phase == :failed -> 0
      conn.phase == :open and conn.drain_at != nil and map_size(conn.pending) == 0 -> 0
      conn.phase == :closed or times == [] -> :infinity
      true -> max(0, Enum.min(times) - now())
    end
  end

  @doc "Cancel a local waiter after its owner exits. This does not cancel host work."
  def cancel(conn, ref) do
    owner!(conn)

    case Enum.find(conn.pending, fn {_, p} -> p.ref == ref end) do
      nil ->
        {:ok, conn, []}

      {_, %{signal: %{type: "dasp.v1.session.open"}}} ->
        close(conn, error(:cancelled, "The session open caller stopped."))

      {id, p} ->
        next = %{
          conn
          | pending: Map.delete(conn.pending, id),
            cancelled: Map.put(conn.cancelled, id, context(p.signal))
        }

        {:ok, next,
         [
           {:reply, ref,
            {:error,
             error(:cancelled, "The local request waiter stopped. Host work can continue.")}}
         ]}
    end
  end

  @doc "Stop new requests and keep the first drain deadline. Call tick/1 to finish."
  def drain(conn, opts \\ []) do
    case protect(fn ->
           owner!(conn)
           timeout = Keyword.get(opts, :timeout, 10_000)
           timeout!(timeout)
           timeout
         end) do
      {:ok, timeout} -> tick(%{conn | drain_at: conn.drain_at || now() + timeout})
      {:error, e} -> {:error, conn, e}
    end
  end

  @doc "Start a bounded close handshake and return terminal results for pending requests."
  def closing(conn, reason \\ error(:closed, "The connection closed locally.")) do
    owner!(conn)

    if conn.phase in [:closing, :closed] do
      {:ok, conn, []}
    else
      events = failures(conn, reason)

      case WebSocket.write(conn.socket, {:close, 1000, ""}) do
        {:ok, socket} ->
          {:ok,
           %{
             conn
             | socket: socket,
               phase: :closing,
               failure: reason,
               pending: %{},
               close_at:
                 min(
                   now() + conn.options.close_timeout,
                   conn.drain_at || now() + conn.options.close_timeout
                 )
           }, events}

        {:error, _} ->
          close(conn, reason)
      end
    end
  end

  @doc "Close the physical socket now and return one terminal result per pending request."
  def close(conn, reason \\ error(:closed, "The connection closed locally.")) do
    owner!(conn)

    if conn.phase == :closed do
      {:ok, conn, []}
    else
      WebSocket.close(conn.socket)

      {:ok,
       %{
         conn
         | phase: :closed,
           failure: reason,
           pending: %{},
           close_at: nil,
           socket: nil,
           sessions: %{},
           cancelled: %{},
           seen: MapSet.new()
       }, failures(conn, reason) ++ [{:error, reason}]}
    end
  end

  defp context(signal),
    do: %{
      signal
      | data: Map.take(signal.data, ~w(session_id command_id actor_id profile after limit)),
        extensions: %{}
    }

  defp failures(conn, e),
    do: Enum.map(conn.pending, fn {_, p} -> {:reply, p.ref, {:error, e}} end)

  defp profile!(conn, signal) do
    if conn.options.validate_profile.(signal) != true,
      do: fail(:profile, "Event does not match the selected profile.")
  end

  defp owner!(conn),
    do:
      if(conn.owner != self(), do: fail(:ownership, "Use the connection in its owning process."))

  defp timeout!(value),
    do:
      if(not is_integer(value) or value < 1 or value > 2_147_483_647,
        do: fail(:configuration, "Supply a positive finite timeout.")
      )

  defp protect(fun) do
    {:ok, fun.()}
  rescue
    e in Error -> {:error, e}
    _ -> {:error, error(:configuration, "Validation or configuration callback failed.")}
  catch
    _, _ -> {:error, error(:configuration, "Validation or configuration callback stopped.")}
  end

  @doc false
  def unary(value, _),
    do: if(is_function(value, 1), do: :ok, else: {:error, "Supply a one-argument callback."})

  @doc false
  def tls_options(value, _) do
    permitted = [
      :cacerts,
      :cacertfile,
      :cert,
      :certfile,
      :key,
      :keyfile,
      :password,
      :depth,
      :versions,
      :verify
    ]

    if is_list(value) and Keyword.keyword?(value) and
         Keyword.get(value, :verify, :verify_peer) == :verify_peer and
         Keyword.keys(value) -- permitted == [],
       do: :ok,
       else: {:error, "TLS peer verification is required."}
  end

  defp error(code, message), do: %Error{code: code, message: message}
  defp now, do: System.monotonic_time(:millisecond)
end
