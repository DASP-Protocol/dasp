# Elixir client

Experimental `dasp_ex`, version `0.1.0-draft.1`, for DASP `draft-01`. Requires Elixir 1.18+ and OTP 27+. This work is in the private fork. No Hex package or site update is published. The project license is pending.

Use `DASP` for the managed client. Use `DASP.Connection` when an existing application process must own the socket. Both use the same functional engine. Mint WebSocket supplies the socket implementation. `jido_signal ~> 3.0.0-beta.4` comes from Hex and supplies Zoi. Req is not a dependency.

Message constructors, replies, and stream elements are ordinary `%Jido.Signal{}` values. Data keys are strings. API options are atoms. Each signal module owns its static Zoi data schema. The package has no general schema framework and uses no lazy schema.

`DASP.Discovery` builds and validates the control documents for the optional
capability-discovery setup contract. These documents are not Signals. They do
not select a profile, authorize a command, or prove that a command is now
available. The actor profile defines the capability universe. Discovery shows
one view of that universe for one authenticated connection and one immutable
snapshot.

The selected `view_items` limit bounds the number of summaries in the complete
advertised view. It does not authorize any command.

Use `DASP.Discovery.enumerate/3` with a binding adapter to read summary pages.
The function checks the actor profile, snapshot, resolved view, order,
continuation progress, and duplicate identities on each page. A callback can
process each summary without retention. Set `accumulate: true` only when the
application needs the complete summary list. Use
`DASP.Discovery.validate_details/4` to check an atomic detail reply against the
completed enumeration.

Schema resources stay outside DASP portable event JSON. A binding adapter must
supply the exact ordered bytes. `DASP.Discovery.ResourceVerifier` checks the
declared length and optional SHA-256 digest as chunks arrive.
`DASP.Discovery.Manifest` checks the closed resource set, required
vocabularies, schema identities, anchors, and references. It never fetches a
URI or file and it does not compile or evaluate a discovered schema.

The actor has one immutable profile URI and version for its lifetime. After
discovery, `session.open` asserts that tuple as a compatibility guard. It does
not choose a profile. Profile-defined threads and episodes share one
session's history and cursor. A separate turn identity is useful only when it
differs from the command identity. An explicit child actor needs independent
discovery and a new session. See the [normative discovery
contract](../../docs/specification/capability-discovery.md).

Signal modules use shared field definitions for identifiers, names, cursors, sequences, profiles, errors, and JSON objects. These definitions are assembled when the modules compile. Complete message schemas remain in their signal modules.

## Local Jido development

In a Jido monofolder, `dev` and `test` use the sibling `jido_signal` checkout
when `../../../jido_signal/mix.exs` exists. Set `DASP_SIGNAL_PATH` to select
another Signal checkout. Production and isolated package consumers use the
Hex requirement unless this variable is set.

Jidoka uses this client at `../dasp/clients/elixir` from its umbrella root.
Edit the client here. Keep protocol definitions and shared conformance fixtures
in the same DASP repository. Run `mix deps.get`, compile, and test from each
consumer after a dependency change.

## Install and test

Add the private checkout to your application's `mix.exs`:

```elixir
{:dasp_ex, path: "/absolute/path/to/dasp/clients/elixir"}
```

Then run `mix deps.get`. From this package directory, run `mix test`. From the repository root, use `npm run clients:test` and `npm run clients:package`. Package checks build local archives and install them in temporary consumer projects. They do not publish packages.

## Setup adapter

Every connection requires `:source`, `:host_source`, `:setup`, and `:validate_profile`.

`setup` receives `%{url: url, source: source, host_source: host_source, status: 101, headers: headers}` in a monitored worker. It must return `:ok` only after checking authenticated host identity and exact mutual selection of the core, profile, binding, encoding, limits, and selected extensions. A refusal or timeout closes the socket before a core operation. Refuse any selected binding, encoding, or extension whose required behavior this client and the application do not implement. The default setup deadline is five seconds.

The adapter and the host must already agree on their application setup format. This package does not define new setup messages or a selection header. A WebSocket upgrade alone does not prove authenticated DASP selection. An adapter which always returns `:ok` is suitable only for a controlled test.

`wss` verifies the certificate chain and hostname. It uses the OS trust roots by default. `tls_options` can supply `cacerts` or `cacertfile`, a client certificate and key, password, depth, or TLS versions. It rejects disabled peer verification and overrides of hostname checks. `ws` requires `allow_insecure: true`; use it only for controlled local tests. Supply application authorization and selection offers through `headers` when your setup adapter requires them.

The profile validator receives each outgoing request, incoming reply, unsolicited signal, and nested replay Update. Return `true` only for the selected profile. Keep this function fast and without external effects. Run application work and storage in the consumer. Do not call the managed client from its profile validator.

## Managed use

The following example uses an application's existing setup and profile adapters. Those adapters are required inputs, rather than sample protocol messages.

```elixir
source = "urn:myapp:agent-manager"
opts = [
  source: source,
  host_source: "urn:myapp:server-agent",
  setup: &MyApp.DASPSetup.verify/1,
  validate_profile: &MyApp.CommerceProfile.valid?/1
]
{:ok, client} = DASP.connect("wss://agents.example/agent", opts)

session = %{
  "session_id" => "assistant-1",
  "actor_id" => "agent-1",
  "profile" => %{"id" => "urn:myapp:commerce", "version" => "1"}
}

# Activate before open. No event is sent to the consumer mailbox without demand.
{:ok, subscription} = DASP.subscribe(client, session_id: "assistant-1")
open = DASP.Signal.SessionOpen.new!(session, source: source)
{:ok, opened} = DASP.request(client, open, timeout: 5_000)
"dasp.v1.session.opened" = opened.type

command = DASP.Signal.Command.new!(%{
  "session_id" => "assistant-1",
  "command_id" => "purchase-123",
  "name" => "task.run",
  "input" => %{"task" => "Find a flight"}
}, source: source)

# Save command.data before this call.
{:ok, receipt} = DASP.request(client, command, timeout: 5_000)
"dasp.v1.receipt" = receipt.type

try do
  subscription
  |> DASP.signals()
  |> Stream.each(&MyApp.apply_and_save_signal/1)
  |> Stream.run()
after
  DASP.close(client)
end
```

A command reply is an admission receipt. Its `disposition` can be `accepted`, `duplicate`, or `rejected`. A rejected receipt is still `{:ok, receipt}`. It does not mean the command completed. Read a saved outcome with `DASP.Signal.OutcomeRead`.

A correlated protocol Failure is also `{:ok, %Jido.Signal{type: "dasp.v1.failure"}}`. Its server error is in `signal.data["error"]`. Local validation, deadline, transport, and delivery errors use `{:error, %DASP.Error{}}`. A timeout or lost connection can leave command admission unknown.

## Custom signals

All 14 core types use `use Jido.Signal` and a static Zoi schema:

| Module under `DASP.Signal` | Draft type |
| --- | --- |
| `SessionOpen` | `dasp.v1.session.open` |
| `SessionOpened` | `dasp.v1.session.opened` |
| `Command` | `dasp.v1.command` |
| `Receipt` | `dasp.v1.receipt` |
| `Update` | `dasp.v1.update` |
| `Progress` | `dasp.v1.progress` |
| `ViewRead` | `dasp.v1.view.read` |
| `View` | `dasp.v1.view` |
| `UpdatesRead` | `dasp.v1.updates.read` |
| `Updates` | `dasp.v1.updates` |
| `OutcomeRead` | `dasp.v1.outcome.read` |
| `Outcome` | `dasp.v1.outcome` |
| `ResyncRequired` | `dasp.v1.resync.required` |
| `Failure` | `dasp.v1.failure` |

Each has native `new/2`, `new!/2`, `validate_data/1`, `schema/0`, `type/0`, `default_source/0`, `datacontenttype/0`, and `dataschema/0` functions. Constructors validate the closed data shape and data limits. They do not create another event struct. The connection and codec check the complete DASP envelope before transmission or receive processing.

```elixir
{:ok, read} = DASP.Signal.OutcomeRead.new(%{
  "session_id" => "assistant-1", "command_id" => "purchase-123"
}, source: source)
{:ok, outcome} = DASP.request(client, read)

{:error, errors} = DASP.Signal.ViewRead.new(%{session_id: "assistant-1"}, source: source)
# Atom data keys are invalid. new! raises for invalid data or Jido metadata.
```

Use `DASP.encode/1` and `DASP.decode/1` for saved or wire events. The codec keeps `specversion: "1.0"`, original event ID, source, time, subject, data, and flat scalar extensions. It does not generate new metadata during decode or replay. It rejects duplicate JSON keys, invalid UTF-8, fractional or imprecise numbers, oversized values, and nested extension attributes. A new request signal can lack correlation; a complete encoded request cannot.

The codec uses the standard Elixir and OTP JSON functions. OTP decoder callbacks check original number tokens before conversion and retain duplicate object keys for validation. They accept exact integer forms such as `3.0` and `30e-1`, but reject `1.00000000000000001`. Jason already comes from Jido Signal. This package does not add a direct Jason dependency because its default number decoding cannot supply these checks. Original Update byte limits include whitespace inside replay pages.

## Requests and attempt identity

`DASP.request/3` waits for one reply or local error. `DASP.request_async/3` returns a local reference after request handoff. Take its terminal result with `DASP.await/3` from the process which made the async request:

```elixir
{:ok, ref} = DASP.request_async(client, command, timeout: 5_000)
# This is a local result wait, not a second protocol request.
case DASP.await(client, ref, timeout: 1_000) do
  {:error, %DASP.Error{code: :wait_timeout}} ->
    DASP.await(client, ref, timeout: 5_000)
  result -> result
end
```

Each accepted local request has one terminal result. An async result remains in a bounded store until its owner takes it or exits. A second take returns `:request`. Completed results still occupy the request bound. `await` wait timeouts leave the request pending. The request deadline returns `:timeout` as its terminal result. Caller exit cancels local delivery; it does not cancel admitted host work. Loss of the runtime makes its outstanding results unavailable and returns a local `:closed` error.

Before wire validation, the engine makes a fresh event ID and `requestid` for each attempt. It replaces a caller-supplied `requestid`. It preserves the caller's original signal and all semantic command data, including `command_id` and `input`. Other flat extension attributes are retained and validated. The pinned draft uses `requestid`; changing its wire name needs a protocol revision.

Replies must match the authenticated host source, attempt ID, expected type, session, command, and immutable actor/profile tuple. Late replies to timed-out or cancelled requests are checked and discarded. An unexpected or mismatched reply fails the connection. The engine retains bounded attempt evidence; drain and reconnect before its tracking bound is reached.

## Bounded signal streams

```elixir
DASP.signals(client, session_id: "assistant-1")
|> Stream.filter(&(&1.type == "dasp.v1.update"))
|> Stream.each(&MyApp.apply_and_save_signal/1)
|> Stream.run()
```

This is a lazy Enumerable made with `Stream.resource/3`. It activates its subscription when enumeration starts. To avoid a startup gap, call `DASP.subscribe/2` before `session.open`, then enumerate that subscription in the same consumer process. A subscription belongs to the process which creates it. For a separate consumer, create the subscription inside that consumer and wait for its activation before opening the session.

The default stream carries unsolicited Update, Progress, and ResyncRequired signals for the selected session. Correlated replies return through `request` or `await`. A stream is a live delivery feed. It is not a complete durable history.

`DASP.next(subscription, timeout: 1_000)` makes demand for one signal. It returns `:wait_timeout` if none arrives; the subscription stays active. Stream enumeration continues across wait timeouts. A failed connection or local overflow raises `DASP.Error` during enumeration. It cannot look like successful stream completion.

```elixir
# Early halt releases only this subscription.
first_ten = client |> DASP.signals(session_id: "assistant-1") |> Enum.take(10)

# Manual delivery also needs explicit release.
{:ok, sub} = DASP.subscribe(client, session_id: "assistant-1")
try do
  DASP.next(sub, timeout: 1_000)
after
  DASP.unsubscribe(sub)
end
```

Each subscription has message and byte bounds. Its queue stays in the managed process; a slow consumer receives only its one requested element. `Enum.take`, exceptions, and consumer exit release subscriptions. Socket processing continues while consumer callbacks run. Overflow returns `:delivery_overflow`, discards that local queue, and requires recovery from the saved applied cursor. It does not create a host ResyncRequired event or a new wire acknowledgement. Other subscriptions and correlated requests can continue.

## Supervision and close

```elixir
opts = Application.fetch_env!(:my_app, :dasp)
children = [{DASP, Keyword.merge(opts, url: "wss://agents.example/agent", name: MyApp.DASPClient)}]
{:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)
{:ok, client} = DASP.connection(MyApp.DASPClient)

# Open sessions explicitly, then make requests.
:ok = DASP.drain(client, timeout: 5_000)
Supervisor.stop(supervisor)
```

`DASP.start_link/1` returns a PID. `DASP.connection/1` gets its public handle. The child spec uses `restart: :temporary`, so failure does not cause an automatic reconnect. Use a distinct child ID for each connection.

An unlinked `DASP.connect/2` client monitors the connecting process and closes when it exits. A supervised client has the supervisor's lifetime. `DASP.close/1` closes the physical socket and rejects pending requests. `DASP.drain/2` first stops new request admission and waits for pending replies within one fixed deadline. Later drain calls join that deadline. Independent guards can close a blocked runtime at the physical deadline. Accepted host work can continue after close.

After physical close, the managed process can retain bounded terminal async results for `await`. Release its subscriptions and consume those results. The connecting process exit or supervisor termination releases the runtime. Reconnect creates a new client; a closed client cannot become live again.

## Existing owning process

The functional interface starts no DASP GenServer. The process which calls `DASP.Connection.connect/2` owns the socket and must serialize all connection operations.

```elixir
{:ok, connection} = DASP.Connection.connect(url, opts)
open = DASP.Signal.SessionOpen.new!(session, source: opts[:source])
{:ok, connection, local_ref} = DASP.Connection.request(connection, open, timeout: 5_000)

receive do
  socket_message ->
    case DASP.Connection.stream(connection, socket_message) do
      {:ok, next_connection, events} -> {next_connection, events}
      :unknown -> MyApp.handle_own_message(socket_message, connection)
    end
end
```

Events are `{:reply, local_ref, {:ok, signal} | {:error, error}}`, `{:signal, signal}`, and `{:error, connection_error}`. A functional request error is `{:error, updated_connection, error}`. Install that returned state. `tick/1` then emits terminal errors for other pending requests after a failed send.

Use `DASP.Connection.next_timeout/1` to set the owning process's local timer. It returns milliseconds or `:infinity`. On that timer, call `tick/1`, install the returned state, and dispatch its events. Socket input also checks request expiry before accepting a reply. Unrelated messages return `:unknown`; route them to the application's own handlers. Drive timers even when no socket data arrives. The functional owner supplies its own bounded event delivery policy.

See [socket_owner.ex](examples/socket_owner.ex) for a complete application process with request correlation, a local timer, and a bounded signal queue. It uses the same engine as the managed client. Its `next/1` reads local memory; it does not poll the DASP host. Domain work and storage occur in its consumer. Production application owners must also handle their request caller lifetimes.

`Connection.drain(connection, timeout: 5_000)` returns updated state and events. Keep driving `tick` and `stream` through close. `Connection.closing/1` starts a close handshake. `Connection.close/1` closes the socket at once. The functional owner is responsible for its physical lifecycle; the engine does not start lifecycle timers or kill that application process.

## Lost receipt and explicit retry

Save the complete command intent before sending. A lost receipt is not a rejection. Reconnect and open the same session before an explicit retry:

```elixir
# saved_intent is loaded from durable storage.
command = DASP.Signal.Command.new!(saved_intent, source: opts[:source])
{:error, %DASP.Error{code: :transport}} = DASP.request(old_client, command)
DASP.close(old_client)

{:ok, new_client} = DASP.connect(url, opts)
{:ok, opened} = DASP.request(new_client,
  DASP.Signal.SessionOpen.new!(session, source: opts[:source]))
"dasp.v1.session.opened" = opened.type

# An application decision. Preserve command_id, name, and input.
{:ok, receipt} = DASP.request(new_client, command)
# A duplicate receipt is still admission information. Read the saved outcome.
{:ok, outcome} = DASP.request(new_client,
  DASP.Signal.OutcomeRead.new!(Map.take(saved_intent, ["session_id", "command_id"]),
    source: opts[:source]))
```

Reconnection, session reopen/recovery, and command retry are separate actions. There is no automatic command retry, resume token, or HTTP early-data send.

## Reconnect and replay from an applied cursor

Never advance the applied cursor on socket receipt, subscription delivery, or enumeration. The application advances it only after applying an Update and durably saving state, cursor, and duplicate evidence together. Progress does not advance it.

Subscribe before opening the new connection's session. Capture the confirmed open cursor as fixed head `H`. Replay from the saved applied cursor through `H`. New page heads do not move `H`. Live updates above `H` remain in the bounded subscription while replay runs.

```elixir
defmodule MyApp.Replay do
  def through(_client, %{"cursor" => cursor} = checkpoint, head, _source, _reduce, _validate_profile, _save)
      when cursor == head, do: checkpoint

  def through(client, checkpoint, head, source, reduce, validate_profile, save) do
    after_cursor = checkpoint["cursor"]
    if head < after_cursor, do: raise(DASP.Error, code: :continuity, message: "Host history is below the saved cursor.")
    read = DASP.Signal.UpdatesRead.new!(%{
      "session_id" => checkpoint["session"]["session_id"],
      "after" => after_cursor,
      "limit" => min(100, head - after_cursor)
    }, source: source)
    {:ok, page} = DASP.request(client, read, replay_head: head)
    "dasp.v1.updates" = page.type
    {:ok, next} = DASP.Checkpoint.apply_updates(checkpoint, page.data["events"], reduce, validate_profile)
    :ok = save.(next) # Atomic durable save, after application.
    through(client, next, head, source, reduce, validate_profile, save)
  end
end

{:ok, client} = DASP.connect(url, opts)
{:ok, sub} = DASP.subscribe(client, session_id: checkpoint["session"]["session_id"])
{:ok, opened} = DASP.request(client,
  DASP.Signal.SessionOpen.new!(checkpoint["session"], source: opts[:source]))
"dasp.v1.session.opened" = opened.type
head = opened.data["cursor"]
checkpoint = MyApp.Replay.through(client, checkpoint, head, opts[:source],
  &MyApp.reduce_update/2, opts[:validate_profile], &MyApp.save_checkpoint/1)

# Read the queued live feed. Apply each Update and save before changing this state.
# Handle Progress without changing the cursor. On ResyncRequired, reopen and replay.
DASP.signals(sub)
|> Enum.reduce(checkpoint, fn signal, saved -> MyApp.apply_and_save(signal, saved) end)
```

`replay_head` is a local request option, with no new wire field. It bounds a recovery read to `H` and rejects a page whose history head falls below `H`. Replay pages must have contiguous updates, correct session/source, valid profile data, and a matching `next`. The codec retains each saved Update's event identity.

Host ResyncRequired cancels pending reads marked with `replay_head`; their late replies are discarded after context checks. Reopen before new operations on that attachment. Local subscription overflow is a separate error. Release that subscription, establish delivery again, and replay from the last durable cursor. If duplicate evidence is missing or history changed, use the protocol's trusted view recovery rules. Do not skip gaps or infer a cursor from delivered events.

`DASP.Checkpoint` checks ordered application and unchanged duplicates. `DASP.Live` remains available for an application-managed recovery state machine. Its returned checkpoint must be saved before installing the changed state. Neither helper supplies storage.

## Limits and transport scope

| Local setting | Default | Option |
| --- | --- | --- |
| Pending requests plus retained async results | 100 | `max_pending_requests` |
| Tracked attempts per connection | 4096 | `max_tracked_requests` |
| Sessions per connection | 100 | `max_sessions` |
| Subscriptions | 100 | `max_subscriptions` |
| Messages per subscription | 100 | `max_subscription_messages` |
| JSON bytes per subscription | 1 MiB | `max_subscription_bytes` |
| Calls waiting for request dispatch | 100 | `max_queued_messages` |
| Retained terms waiting for dispatch | 2 MiB | `max_queued_bytes` |
| WebSocket assembly | 2 MiB | `max_buffer_bytes` |
| Frames in one socket read | 1024 | `max_frames_per_read` |
| Upgrade response | 64 KiB | `max_handshake_bytes` |
| Core text message | 1 MiB maximum | `max_message_bytes` |
| Request reply deadline | 10 s | `timeout` |
| Connect, upgrade, and setup deadlines | 5 s each | `connect_timeout`, `setup_timeout` |
| Socket write deadline | 2 s | `write_timeout` |
| Close handshake deadline | 1 s | `close_timeout` |

These are local controls. The setup adapter must confirm that selected binding limits fit them. The pinned core also limits an Update to 64 KiB, application strings to 64 KiB, containers to 1024 entries, and profile payload depth to 16. It permits exact integers only within the portable JSON integer range.

The socket driver uses HTTP/1 WebSocket upgrade and one structured CloudEvents JSON event per text message. It supports fragments, masked client frames, ping replies, and close handshakes. It offers no WebSocket compression. Binary CloudEvents encoding, HTTP polling, HTTP/2 or HTTP/3 streams, payload encryption, authority proof verification, and host admission require separate implementations. Flat extension attributes can be carried, but their presence does not implement their security contract.

Sessions on a shared WebSocket share its network and failure boundary. Use separate connections when independent session failure is required.

## Existing exchange and recovery APIs

`DASP.Client`, `DASP.Duplex`, `DASP.Live`, `DASP.Checkpoint`, and `DASP.OutputQueue` remain available. The older exchange API accepts an application's complete authenticated transport function and uses `open`, `submit`, and explicit read helpers. It turns a protocol Failure into `:remote_failure`; the new request API returns the Failure signal. Do not mix their result rules.

Run `mix run examples/recorded.exs` for the existing local reply-adapter example. It starts no host. `DASP.Duplex` is still a transport-independent dispatcher; it does not itself open a socket. The new managed client uses `DASP.Connection` directly.

Tests cover the shared strict JSON and recovery fixtures, all custom signal modules, both public APIs, concurrent and late replies, caller exit, bounded subscriptions, stream halt, failure propagation, fixed replay heads, resync, verified TLS, real socket fragments, ping, and close. Local socket tests do not prove interoperability with a released authenticated DASP host or an encryption implementation.
