defmodule DASP.Client do
  @moduledoc """
  Transport-independent DASP draft-01 client built on Jido Signal.

  Each call returns a validated Jido.Signal or a DASP.Error. submit/3 returns
  an admission receipt. Use read_outcome/3 for the saved outcome.
  There are no automatic retries. Save command IDs and their data before submission.

  The transport is a function (json, timeout_ms) -> {:ok, json} | {:error, reason}.
  It runs in a monitored worker. It must establish the authenticated host context,
  negotiate the binding, and obey the supplied deadline.
  """
  import DASP.Error, only: [fail: 2, fail: 3]
  alias DASP.Wire
  @enforce_keys [:source, :host_source, :transport, :validate_profile]
  defstruct [:source, :host_source, :transport, :validate_profile, timeout: 10_000]
  @type t :: %__MODULE__{}
  @type transport :: (binary(), pos_integer() -> {:ok, binary()} | {:error, term()})

  @spec new(keyword()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def new(opts) do
    Wire.protect(fn ->
      source = Keyword.get(opts, :source)
      host = Keyword.get(opts, :host_source)
      transport = Keyword.get(opts, :transport)
      profile = Keyword.get(opts, :validate_profile)
      timeout = Keyword.get(opts, :timeout, 10_000)

      if not uri?(source) or not uri?(host) or not is_function(transport, 2) or
           not is_function(profile, 1) or
           not is_integer(timeout) or timeout < 1 or timeout > 2_147_483_647,
         do:
           fail(
             :configuration,
             "Supply absolute source URIs, transport, profile validator, and positive timeout."
           )

      %__MODULE__{
        source: source,
        host_source: host,
        transport: transport,
        validate_profile: profile,
        timeout: timeout
      }
    end)
  end

  def open(client, session),
    do: request(client, "session.open", "session.opened", session, session)

  def submit(client, session, command),
    do:
      request(
        client,
        "command",
        "receipt",
        Map.put(command, "session_id", session["session_id"]),
        session
      )

  def read_view(client, session),
    do: request(client, "view.read", "view", %{"session_id" => session["session_id"]}, session)

  def read_updates(client, session, after_cursor, limit \\ 100),
    do:
      request(
        client,
        "updates.read",
        "updates",
        %{"session_id" => session["session_id"], "after" => after_cursor, "limit" => limit},
        session
      )

  def read_outcome(client, session, command_id),
    do:
      request(
        client,
        "outcome.read",
        "outcome",
        %{"session_id" => session["session_id"], "command_id" => command_id},
        session
      )

  defp request(client, kind, reply, data, session) do
    Wire.protect(fn ->
      event = %{
        "specversion" => "1.0",
        "id" => id(),
        "source" => client.source,
        "type" => "dasp.#{kind}.v1",
        "datacontenttype" => "application/json",
        "requestid" => id(),
        "data" => data
      }

      event = Wire.to_signal!(event)
      wire = Wire.encode!(event)
      profile!(client.validate_profile, event)
      response = exchange!(client, wire) |> Wire.decode!()

      if response.source != client.host_source or
           response.extensions["requestid"] != event.extensions["requestid"],
         do: fail(:correlation, "Reply source or request ID differs from the request context.")

      if response.type == "dasp.failure.v1",
        do: fail(:remote_failure, response.data["error"]["message"], response.data["error"])

      if response.type != "dasp.#{reply}.v1", do: fail(:correlation, "Unexpected reply type.")
      d = response.data

      if d["session_id"] != session["session_id"] or
           (Map.has_key?(data, "command_id") and d["command_id"] != data["command_id"]) or
           (Map.has_key?(d, "actor_id") and
              (d["actor_id"] != session["actor_id"] or d["profile"] != session["profile"])),
         do: fail(:correlation, "Reply does not match the session, actor, profile, or command.")

      if reply == "updates" do
        page!(response, data["after"], data["limit"])

        Enum.each(d["events"], fn update ->
          if update["source"] != client.host_source,
            do: fail(:correlation, "Update producer differs from the host context.")

          profile!(client.validate_profile, Wire.to_signal!(update))
        end)
      end

      profile!(client.validate_profile, response)
      response
    end)
  end

  @doc false
  def profile!(validator, event) do
    if validator.(event) != true, do: fail(:profile, "Event does not match the selected profile.")
  end

  @doc false
  def page!(%Jido.Signal{data: d}, after_cursor, limit) do
    if d["after"] != after_cursor or d["after"] > d["head"] or length(d["events"]) > limit or
         (d["after"] < d["head"] and d["events"] == []),
       do: fail(:replay, "Invalid replay page bounds.")

    next =
      Enum.reduce(d["events"], after_cursor, fn event, cursor ->
        update = event["data"]

        if update["session_id"] != d["session_id"] or update["sequence"] != cursor + 1 or
             update["sequence"] > d["head"],
           do: fail(:replay, "Replay events must be contiguous and in the requested session.")

        update["sequence"]
      end)

    if d["next"] != next, do: fail(:replay, "Replay next differs from the last update.")
  end

  defp exchange!(client, wire) do
    parent = self()
    # A process alias discards late messages after the deadline.
    tag = :erlang.alias()

    {pid, monitor} =
      spawn_monitor(fn ->
        result =
          try do
            client.transport.(wire, client.timeout)
          rescue
            error -> {:error, error}
          catch
            kind, reason -> {:error, {kind, reason}}
          end

        send(tag, {tag, parent, result})
      end)

    try do
      receive do
        {^tag, ^parent, {:ok, text}} when is_binary(text) ->
          text

        {^tag, ^parent, {:error, reason}} ->
          fail(:transport, "Transport failed. Command admission may still have occurred.", reason)

        {^tag, ^parent, other} ->
          fail(:transport, "Invalid transport result.", other)

        {:DOWN, ^monitor, :process, ^pid, reason} ->
          fail(:transport, "Transport worker stopped.", reason)
      after
        client.timeout ->
          Process.exit(pid, :kill)
          fail(:timeout, "Reply deadline expired. Command admission may still have occurred.")
      end
    after
      :erlang.unalias(tag)
      Process.demonitor(monitor, [:flush])

      receive do
        {^tag, ^parent, _} -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp id, do: Jido.Signal.ID.generate!()
  defp uri?(value) when is_binary(value), do: Regex.match?(~r/^[a-z][a-z0-9+.-]*:\S+$/i, value)
  defp uri?(_), do: false
end
