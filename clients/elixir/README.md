# Elixir client

Experimental `dasp_ex`, version `0.1.0-draft.1`, for DASP `draft-01`. Requires Elixir 1.18 or later. No Hex release is published. The project license is pending.

The Elixir client is **built on [Jido Signal](https://github.com/agentjido/jido_signal)** and depends on `jido_signal ~> 3.0.0-beta.4`. Client replies, profile callbacks, and reducer events use `%Jido.Signal{}`. Command inputs, session options, and saved checkpoints use string-key maps. This dependency applies to the Elixir implementation; DASP remains a language-independent protocol.

## Run the recorded example

From the repository root:

```sh
cd clients/elixir
mix deps.get
mix run examples/recorded.exs
```

See [recorded.exs](examples/recorded.exs). It uses a local reply adapter, not a server or network binding. See the [shared client guide](../README.md) for test coverage and limits.

## Install from a local checkout

Add a path dependency to your application's `mix.exs`:

```elixir
{:dasp_ex, path: "/absolute/path/to/dasp/clients/elixir"}
```

Then run `mix deps.get`. From the package directory, run `mix test` to use the shared repository fixtures. Build a review archive with `mix hex.build --output /absolute/path/to/dasp_ex.tar`. CI also provides archives as [workflow artifacts](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml).

## Connect an application

```elixir
{:ok, client} = DASP.Client.new(
  source: "urn:example:client:one",
  host_source: "urn:example:host:one",
  transport: &MyApp.DASPTransport.request/2,
  validate_profile: &MyApp.CounterProfile.valid_event?/1,
  timeout: 10_000
)
session = %{
  "session_id" => "session-counter",
  "actor_id" => "counter-main",
  "profile" => %{"id" => "urn:example:dasp:counter", "version" => "1"}
}
{:ok, _opened} = DASP.Client.open(client, session)

# Save this identity and exact input before the first attempt.
command = %{"command_id" => "command-add-1", "name" => "counter.add", "input" => %{"amount" => 3}}
{:ok, %Jido.Signal{} = receipt} = DASP.Client.submit(client, session, command)
receipt.data["disposition"]
# The receipt is not a completed outcome.
{:ok, outcome} = DASP.Client.read_outcome(client, session, command["command_id"])
```

Your transport implements `request(json, timeout_ms)` and returns `{:ok, json}` or `{:error, reason}`. It supplies the authenticated channel, binding selection, and framing. Return the complete UTF-8 reply. Do not decode it first: that can discard duplicate keys or number precision.

The callback runs in a monitored worker. A deadline stops that worker and returns a timeout. The adapter must close its I/O resources when the worker stops. It does not cancel admitted server work. There are no automatic retries.

The profile callback receives a `%Jido.Signal{}` and must return `true` only when it is valid for the selected profile. It runs before send and after receive, including each update in a replay page. A `false` result stops the operation. Callback exceptions propagate to the caller. Use a separate configured client if different profile validators are needed.

## Signals and the wire format

Use `DASP.Wire` to encode and decode DASP traffic. Jido Signal V3 and DASP use `specversion: "1.0"`. The only direct runtime package dependency is `jido_signal`. OTP 27 or later supplies JSON parsing. It keeps the original event identity, data, time, subject, schema URI, and scalar extensions. It does not add a timestamp to a received event.

Read correlation from `signal.extensions["requestid"]` and payload fields from `signal.data`. DASP extensions remain flat scalar values in `signal.extensions`. The codec rejects nested extension values, core-attribute collisions, and binary payloads. Route messages through the transport adapter.

Do not use `Jido.Signal.serialize/1` or `deserialize/1` for DASP traffic. The DASP codec also enforces strict JSON parsing, the draft schema, and size limits.

```elixir
{:ok, %Jido.Signal{} = signal} = DASP.Wire.decode(json)
{:ok, wire_map} = DASP.Wire.to_map(signal)
{:ok, signal} = DASP.Wire.to_signal(wire_map)
{:ok, json} = DASP.Wire.encode(signal)
```

Replay pages keep their nested events as JSON maps in `page.data["events"]`. The client validates each nested event as a signal before calling the profile validator. Checkpoint functions accept signals or wire maps and pass signals to the reducer. Checkpoint evidence stays in JSON form for storage.

## API

Each client operation returns `{:ok, %Jido.Signal{}}` or `{:error, %DASP.Error{}}`. Signal data uses string keys. The package creates no atoms from wire fields.

| Function | Reply |
| --- | --- |
| `Client.open/2` | `session.opened` |
| `Client.submit/3` | Admission `receipt` |
| `Client.read_view/2` | Coherent `view` |
| `Client.read_updates/3` or `/4` | `updates` page; default limit 100 |
| `Client.read_outcome/3` | Pending or settled `outcome` |
| `Wire.decode/1` / `Wire.encode/1` | Validated signal / JSON bytes |
| `Wire.to_signal/1` / `Wire.to_map/1` | Validated signal / DASP wire map |

`DASP.Wire` validates core shapes and limits. It does not authenticate the producer or check application semantics. Use the client for request/reply checks. The adapter must authenticate push events before recovery code applies them.

## Recover state

```elixir
{:ok, view} = DASP.Client.read_view(client, session)
{:ok, checkpoint} = DASP.Checkpoint.from_view(view, &MyApp.CounterProfile.valid_event?/1)
:ok = MyApp.Store.save_checkpoint(checkpoint)
{:ok, page} = DASP.Client.read_updates(client, session, checkpoint["cursor"])
{:ok, next} = DASP.Checkpoint.apply_updates(
  checkpoint, page.data["events"],
  &MyApp.CounterProfile.reduce/2,
  &MyApp.CounterProfile.valid_event?/1
)
:ok = MyApp.Store.save_checkpoint(next)
```

Save state, cursor, and evidence in one transaction before acknowledging delivery. On restart, load that checkpoint, open the same session, and recover unresolved commands. For a polling-only binding, continue reading under its paging policy until `page.data["next"] == page.data["head"]`. For the [first WebSocket binding](../../docs/specification/websocket-live-delivery.md#dasp-ws-003), confirm the new attachment and retain its fixed head `H`. Buffer live events, replay through `H`, then apply the buffer in sequence. A newer page head does not move `H`. For example, saved cursor 3, `H = 6`, and page 4–6 with head 7 require one recovery read, then buffered event 7. An equal open of a retained attachment does not restart replay. Use `DASP.Live` for this transition.

The reducer must be pure. A failed batch returns no new checkpoint. Duplicate evidence stays in the checkpoint and can grow with history. Missing evidence for an old update requires a trusted view or a stop.

Error codes include `:invalid_json`, `:invalid_event`, `:configuration`, `:transport`, `:timeout`, `:correlation`, `:remote_failure`, `:profile`, `:replay`, `:checkpoint`, `:gap`, `:changed_update`, and `:missing_evidence`. A remote failure keeps the server error in `detail`. Transport failures and timeouts leave admission unresolved.


**Experimental API change:** Earlier source revisions returned wire maps. Use `signal.type`, `signal.data`, and `signal.extensions["requestid"]` with the current client. Convert a signal with `DASP.Wire.to_map/1` when an application needs the full wire map.


## Live delivery on a duplex channel

`DASP.Duplex` connects the existing client to a channel that can send requests and receive replies and pushes. `DASP.Live` tracks one session on that connection. It retains a fixed replay head, checks live sequence numbers, buffers events during replay, and cancels obsolete recovery reads after `resync.required`. Normal live operation does not poll history.

The application must supply an authenticated channel with the binding already selected. Feed the original core JSON to `DASP.Duplex.received/2` after authentication and decryption. The driver must limit frame assembly before it gives a complete message to the dispatcher. These modules do not open a WebSocket, select a binding, set up encryption, or send health checks. Those wire formats need a separate specification and implementation.

The following example assumes a trusted `checkpoint`, a pure `reduce` function, a profile validator, and application channel functions. `save_atomically` must save the complete checkpoint and return `:ok` or `{:error, %DASP.Error{}}`.

```elixir
{:ok, live} = DASP.Live.new(checkpoint: checkpoint,
  client_source: "urn:example:client:one", reduce: reduce,
  validate_profile: validate_profile)

on_event = fn notice, current ->
  transition = case notice do
    {:sent, event, wire} -> DASP.Live.sent(current, wire,
      replay: event.type == "dasp.v1.updates.read" and current.phase == :replay)
    {:received, _, wire} -> DASP.Live.received(current, wire)
    {:timeout, id} -> DASP.Live.timeout(current, id)
    {:closed, _} -> {:ok, DASP.Live.close(current)}
  end
  with {:ok, next} <- transition,
       :ok <- (if next.action == :save, do: save_atomically.(next.checkpoint), else: :ok) do
    {:ok, next, cancel: MapSet.to_list(next.cancelled)}
  end
end

{:ok, pid} = DASP.Duplex.start_link(host_source: checkpoint["host_source"],
  send: send_core, close: close_channel, on_event: on_event, handler_state: live)
channel = DASP.Duplex.channel(pid)
{:ok, client} = DASP.Client.new(source: "urn:example:client:one",
  host_source: checkpoint["host_source"], transport: DASP.Duplex.transport(channel),
  validate_profile: validate_profile)
{:ok, _} = DASP.Client.open(client, checkpoint["session"])

# The driver calls DASP.Duplex.received(channel, core_json) in receive order.
# Outside on_event, read DASP.Duplex.state(channel) and call DASP.Live.next_read/1.
# While it returns a map, call Client.read_updates with that after and limit.
# Stop recovery reads when it returns nil. New updates then come from the stream.
```

The `send` callback must hand off one core JSON message and return `:ok`. It must not wait for a reply. `close` takes no arguments. `on_event` runs in wire order. Return `{:ok, state}` or `{:ok, state, cancel: ids}`. Return cancellation IDs from the resync callback to apply cancellation before the next incoming message. `cancel/2` is a separate asynchronous control function.

Save state, cursor, session, host source, and duplicate evidence in one atomic operation. Return the new handler state only after the save succeeds. A callback error closes the connection and rejects pending requests. The old checkpoint remains available for recovery. The reducer must have no external side effects. The client preserves a transport's `%DASP.Error{}` code; other transport errors use `:transport`.

Run recovery control outside `on_event`. The callback must not wait for a new request or call the dispatcher: replies use the same process. After a resync, `action == :reopen` means open the same session again. `action == :wait_open` means wait for the existing open reply. Then use `next_read/1` until it returns `nil`. If open fails, decide whether to retry outside the callback. An open deadline closes the entire connection. Make new dispatcher and recovery objects on a new connection, using the saved checkpoint. Do not retry commands automatically. Supervise the dispatcher and close the application channel if its process stops.

Mark only recovery reads with `replay: true`. Ordinary explicit history reads do not change the checkpoint. The example reserves reads during replay for recovery. An application that also makes ordinary reads at that time must distinguish them in its callback. Progress is temporary and does not change the saved cursor. For several sessions, route each event to a separate `DASP.Live`; use one dispatcher for the connection.

Cancellation rejects local requests and discards structurally valid late replies. It does not cancel server work. Cancelling a pending open closes the connection. Request IDs must be unique across the connection. Obtain the channel handle once. Use it for receive calls so queue limits apply before messages enter the process mailbox.

| Local limit | Default | Option |
| --- | --- | --- |
| Queued messages, including active callback work | 100 | `max_queued_messages` |
| Queued core JSON bytes | 1 MiB | `max_queued_bytes` |
| Pending requests | 100 | `max_pending_requests` |
| Request IDs retained for one connection | 4096 | `max_tracked_requests` |
| Buffered live events during replay | 100 | `max_buffered_events` on `DASP.Live` |
| Encoded buffered event bytes | 1 MiB | `max_buffered_bytes` on `DASP.Live` |
| Events per recovery read | 100 | `page_limit` on `DASP.Live` |

Reconnect before the request tracking limit is reached. Queue or buffer overflow closes the connection. A recovery transition error used without the dispatcher requires the application to close the connection. Additional error codes are `:live`, `:continuity`, `:overflow`, `:closed`, and `:resync`.

Tests execute all 16 shared delivery traces against `DASP.Live`. In-memory channel tests check reply ordering, replay overlap, cancellation, deadlines, storage failures, and local limits. They do not prove WebSocket host conformance or cryptographic interoperability.
