# jido_seigyo

`jido_seigyo` is the data boundary for the Seigyo Protocol. The protocol is
the client-facing control contract for Jido Code. WebSocket is the current
transport, but it is not part of the protocol identity.

This application owns:

- versioned Jido Signal types;
- closed Zoi schemas for Signal data;
- typed IDs and portable value limits;
- stable client error data;
- the current coding-profile capability catalog; and
- current and draft schemas for coding-session features; and
- the standalone `Jido.Seigyo.Client` WebSocket client.

This application does not own a Session store, an Agent process, command
admission, access control, or a queue. The Jido Code server enforces those
rules. `Jido.Seigyo.Client` owns WebSocket transport and client ergonomics,
but it does not implement server policy.

The acceptance application remains separate. It starts a real server and
checks the public client from outside the implementation.

## Frozen coding v1 contract

`priv/seigyo/coding-v1/contract.json` identifies the exact baseline by protocol,
profile, binding, and content digest. It includes the named normative file
list. The bundle contains schemas, operation metadata, custom rules, test
vectors, requirements, and case IDs. `provenance.json` records the source
revision separately. See [release policy](../../docs/seigyo/release-policy.md).

From this application, export and check the contract without starting a server:

```sh
mix run --no-start scripts/export_contract.exs /tmp/seigyo-coding-v1
python3 ../jido_code_acceptance/scripts/verify_contract.py /tmp/seigyo-coding-v1
```

The exporter refuses to replace changed files. Repeated exports have the same
bytes. The Python checker uses only the standard library and release files.
Use its `--digest` option with a trusted digest to check an expected contract.
The digest does not authenticate an endpoint. The frozen bundle must not be
regenerated from a later implementation; publish a new bundle for a new contract.

## Protocol status

The package has two separate catalogs.

**Current** operations and Signal types are returned by
`Jido.Seigyo.capabilities/1`. The server can advertise only these items.

**Draft** operations and Signal types have closed data schemas, but they have
no advertised server implementation. They are available through
`Jido.Seigyo.draft_operations/0` and the three `draft_*_signal_types/0`
functions. A successful schema validation does not mean that an endpoint
supports a draft operation.

This split permits TDD work on the data boundary without making a false
server capability claim.

`Jido.Seigyo.Catalog` is the single operation and control inventory. It also
names event authority, retry categories, failure vocabulary, and requirement
references. Client and adapter dispatch use this inventory. Live policy and
runtime functions stay in the server and adapter.

Client structs select fields from canonical schemas through
`Jido.Seigyo.Schema`. Their converters validate the complete payload before
they build typed values. Local projections can flatten content; they cannot
discard unknown wire fields. See [definition rules](../../docs/seigyo/definitions.md).

## Signal envelope

Every Seigyo Signal uses a Jido CloudEvents envelope with this main shape:

```json
{
  "specversion": "1.0",
  "id": "018f1a1a-7b3c-7a00-8000-000000000001",
  "source": "/jido/code/client",
  "type": "jido.client.v1.session.open",
  "data": {}
}
```

Client Signals use `/jido/code/client` as their default source. Server Signals
use `/jido/code/server`. A version 1 type starts with `jido.client.v1.` and
ends with the message name. The source states the logical sender role. It is
not an identity or access credential.

`Jido.Signal.deserialize/1` validates and decodes the envelope.
`Jido.Seigyo.validate/1` then checks the Signal type and its closed data
schema. The transport must also enforce its source, envelope, authentication,
and encoded frame-size rules.

The envelope ID names one delivery. It is not a command retry key or a saved
event cursor. A replayed saved event can have a new envelope ID.

## Current coding profile

The current capability catalog has these operations:

| Operation | Purpose |
| --- | --- |
| `open` | Open or recover one Session. |
| `submit` | Admit one `submit_text` Command. |
| `updates` | Read ordered saved Updates after a cursor. |
| `history` | Read projected conversation entries. |
| `view` | Read one coherent Session view. |
| `trace` | Read bounded activity for one Command. |
| `workspace_changes` | Read bounded Git status and patch data. |
| `workspaces` | List configured local Workspaces visible to the principal. |
| `workspace_configure` | Create or update one versioned Workspace configuration. |
| `execution_catalog` | Read safe execution targets and Sandbox profiles. |
| `configuration` | Read the effective and pending Session configuration. |
| `configuration_history` | Read ordered saved configuration revisions. |
| `configure` | Change revisioned Session configuration. |
| `fork` | Create a fork or side chat from the current committed Session head. |
| `submit_turn` | Admit one active or queued coding turn. |
| `steer_turn` | Add one idempotent steering mutation to the active turn. |
| `cancel_turn` | Request cancellation of an active or queued turn. |
| `result` | Read the normalized result for one Command. |
| `attachment_begin` | Begin one bounded immutable Attachment upload. |
| `attachment_chunk` | Add one ordered Attachment chunk. |
| `attachment_commit` | Verify and commit one Attachment. |

The current transport controls are `watch_progress` and `watch_updates`.
Controls manage live delivery. They are not durable commands.

For application-controlled delivery, call `watch_updates/3` with
`delivery: :acknowledged`. Apply and save each Update returned in its replay
page, then call `ack_update/2` with that complete value, in order. Do the same
for each later `{:jido_code_update, client, update}` message. Live Updates wait
until the replay page is acknowledged. Acknowledgement is local; the caller
must save its state and applied cursor together. After resync or reconnect,
read again from that saved cursor.

The default `:automatic` mode records delivery, not successful application.
`Jido.Seigyo.Replay.check/2` and `commit/2` provide a pure bounded comparison
helper. See [replay rules](../../docs/seigyo/replay.md) and the portable vectors
in `priv/seigyo/replay-v1/vectors.json`.

### Current Signal types

| Direction | Signal | Type |
| --- | --- | --- |
| Client to server | `SessionOpen` | `jido.client.v1.session.open` |
| Server to client | `SessionOpened` | `jido.client.v1.session.opened` |
| Client to server | `Command` | `jido.client.v1.command` |
| Server to client | `Receipt` | `jido.client.v1.receipt` |
| Server to client | `View` | `jido.client.v1.view` |
| Server to client | `UpdatesPage` | `jido.client.v1.updates.page` |
| Server to client | `HistoryPage` | `jido.client.v1.history.page` |
| Server to client | `Update` | `jido.client.v1.update` |
| Server to client | `Progress` | `jido.client.v1.progress` |
| Server to client | `ResyncRequired` | `jido.client.v1.resync.required` |
| Server to client | `Trace` | `jido.client.v1.trace` |
| Server to client | `WorkspaceChanges` | `jido.client.v1.workspace.changes` |
| Server to client | `Workspaces` | `jido.client.v1.workspaces` |
| Client to server | `WorkspaceConfigure` | `jido.client.v1.workspace.configure` |
| Server to client | `WorkspaceConfigured` | `jido.client.v1.workspace.configured` |
| Server to client | `ExecutionCatalog` | `jido.client.v1.execution.catalog` |
| Server to client | `Failure` | `jido.client.v1.failure` |
| Server to client | `SessionConfiguration` | `jido.client.v1.session.configuration` |
| Server to client | `SessionConfigurationsPage` | `jido.client.v1.session.configurations.page` |
| Client to server | `SessionConfigure` | `jido.client.v1.session.configure` |
| Server to client | `SessionConfigured` | `jido.client.v1.session.configured` |
| Client to server | `SessionFork` | `jido.client.v1.session.fork` |
| Server to client | `SessionForked` | `jido.client.v1.session.forked` |
| Client to server | `TurnSubmit` | `jido.client.v1.turn.submit` |
| Server to client | `TurnReceipt` | `jido.client.v1.turn.receipt` |
| Client to server | `TurnSteer` | `jido.client.v1.turn.steer` |
| Client to server | `TurnCancel` | `jido.client.v1.turn.cancel` |
| Server to client | `TurnControlled` | `jido.client.v1.turn.controlled` |
| Server to client | `Result` | `jido.client.v1.result` |
| Client to server | `AttachmentBegin` | `jido.client.v1.attachment.begin` |
| Client to server | `AttachmentChunk` | `jido.client.v1.attachment.chunk` |
| Client to server | `AttachmentCommit` | `jido.client.v1.attachment.commit` |
| Server to client | `Attachment` | `jido.client.v1.attachment` |

The version 1 `Command` has one kind: `submit_text`. Its Command ID is the
stable retry key. A retry sends the same Command data with the same ID.

## Standalone client

`Jido.Seigyo.Client` is an independent WebSocket client. It needs only the
server URL and an access token. It does not depend on the Server, Web, TUI,
GPUI, or acceptance applications.

```elixir
{:ok, client} =
  Jido.Seigyo.Client.start_link(
    url: "http://127.0.0.1:4000",
    token: token
  )

{:ok, session} = Jido.Seigyo.Client.open(client)
{:ok, receipt} = Jido.Seigyo.Client.submit_text(client, session, "Inspect the project")
{:ok, view} = Jido.Seigyo.Client.view(client, session)
```

The client owns WebSocket state, request references, strict Signal encoding
and decoding, and typed result values. It exposes replay, subscriptions,
attachments, configuration, forks, traces, Workspaces, and execution catalog
operations without exposing Phoenix frames or raw Signal payloads.

The client is fail-stop after a WebSocket failure. A caller starts a new
client, opens the same Session, and resumes from its saved Update cursor.
This keeps retry and possible-effect decisions with the application.

A `Receipt` reports admission only. It does not report the model result. An
accepted or duplicate Receipt points to the saved admission sequence. A
rejected Receipt has an error and no saved position.

An `Update` is a saved event with a positive Session sequence. The current
closed union has these event types:

- `command_accepted`;
- `turn_started`;
- `turn_steered`;
- `turn_cancel_requested`;
- `command_completed`;
- `command_failed`;
- `command_cancelled`;
- `command_uncertain`;
- `session_configured`; and
- `context_compacted`.

An `UpdatesPage` echoes the exclusive `after_sequence` request cursor and
contains same-Session, ascending, contiguous Update data. The first item, when
present, is exactly `after_sequence + 1`.
`Progress` is a temporary full snapshot and has no durable cursor. A live
delivery gap uses `ResyncRequired`; a stored replay gap uses `Failure` with
the `gap` code. A client advances its durable cursor only after it applies an
Update.

`View` contains a bounded coherent cut of Session state. `HistoryPage` has a
separate projected-message cursor. `Trace` gives bounded command activity.
`WorkspaceChanges` returns safe Git change data and never returns a physical
Workspace path.

The authorized `workspaces` administration read returns each configured host
file path and its separate Sandbox runtime path. `workspace_configure` binds
one stable Workspace ID to one local file path. The file path cannot change
for that ID. The name and runtime path use optimistic Workspace versions and
cannot change during an active Workspace lease. A Mutation ID retry returns
the first saved result, including its original Workspace version. Reuse with
different request data fails. This path data is not part of
Session View, Trace, Result, or Workspace Changes.

## Coding-session contracts

The catalog prepares the protocol for long-running coding Sessions. The
capability manifest identifies the current operations and Update variants.
Session lineage and Attachments are current contracts.

| Area | Types | Status and intent |
| --- | --- | --- |
| Session configuration | `SessionConfigure`, `SessionConfiguration`, `SessionConfigured` | Current. Read, change, and report revisioned effective or pending configuration. |
| Session lineage | `SessionFork`, `SessionForked` | Current. Create a fork or side chat from the coherent current Session head. |
| Turn control | `TurnSubmit`, `TurnReceipt`, `TurnSteer`, `TurnCancel`, `TurnControlled` | Current. Keep queued turns, active steering, and cancellation as distinct intents with typed, idempotent results. |
| Attachments | `AttachmentBegin`, `AttachmentChunk`, `AttachmentCommit`, `Attachment` | Current. Upload and verify immutable, bounded content before a turn refers to it. Durable server profiles recover partial and terminal state. |
| Results | `Result` | Current data type. Return one normalized result while server-side subagents remain private. |
| Context | `ContextCompacted` | Draft standalone push type. The current durable Update variant reports compaction. |

### Session configuration

`SessionConfig` is a closed snapshot or patch schema. A full coding
configuration contains:

- a model ID and reasoning level;
- a context mode, target token count, recent-turn preservation count, and
  compaction policy;
- bounded skill and plugin references;
- one server-owned tool-profile identity;
- a logical Workspace ID, isolation policy, and network policy; and
- bounded Session instructions.

An effective and a pending configuration have separate revisions. A client
uses an expected revision for a change. The server decides whether the change
can apply now or only to a later command. An active command keeps its pinned
configuration. The server records a model or other configuration change in
the `session_configured` Update before later work uses it.

Every full configuration has a portable SHA-256 digest. The digest covers its
semantic fields, including the tool profile, and excludes its revision and
effective or pending state. The server saves every revision and exposes it
through the bounded `configuration_history` read. A Result and Trace identify
the exact configuration digest and tool profile used by their Command. The
server rejects new work when the saved tool profile is not available.

The execution policy does not expose a host path, process ID, container ID,
or credential. A Workspace is the stable logical code tree. Isolation and
network fields state requested policy. The server owns the physical execution
placement and checks whether it can satisfy that policy.
The safe execution catalog gives each Sandbox profile a nullable
`workspace_runtime_root`. A client uses this guest-only root when it configures
a Workspace for that profile. It is not a host locator.

### Forks and side chats

`SessionFork` uses a Mutation ID and names the current committed parent event
cursor. Version 1 rejects an older cursor because it does not store historical
configuration and Workspace checkpoints.
An exact retry returns the same child. Reuse of the Mutation ID with different
data fails with a conflict. The child has its own Session ID, Agent, Thread,
event stream, configuration revisions, and context revisions.

The coding client defaults a fork to a managed physical Workspace snapshot.
The snapshot includes committed and uncommitted files present when the server
accepts the fork. A side chat defaults to the same Workspace with read-only
tool access. The server enforces this access rule; the Signal does not expose a
host path. Parent and child histories remain available after server restart.

### Turns, attachments, and results

`TurnSubmit` owns a Command ID and can request queueing or busy rejection.
`TurnSteer` and `TurnCancel` own Mutation IDs and target an existing Command
ID. They do not create queued turns. `TurnReceipt` reports admission and the
initial `active` or `queued` state. `TurnControlled` reports an applied or
duplicate steer or cancel mutation. A rejected control returns `Failure`.

An Attachment is immutable after commit. The flow declares its size,
SHA-256 digest, media type, and purpose, sends ordered base64 chunks, and then
requests commit. A turn can refer only to an Attachment that the server has
verified and marked ready. A durable server profile saves each accepted state
before its reply. After restart, a client can retry the last accepted chunk
and resume at the reported cursor. The memory profile is process-local.

A normalized `Result` identifies its Session, Command, model, configuration
revision and digest, tool profile, and context revision. Its closed block list can contain Markdown,
Attachment references, artifact references, Workspace changes, and citations.
Its `completion` value is `execution`; a completed execution is not a claim of
correctness, verification, approval, or publication. Usage states whether
token counts are reported, estimated, mixed, or unavailable. Unknown token
counts stay null. It also has an explicit reasoning visibility value. It does
not expose the server's internal subagent graph. Aggregate block data is
limited to 256 KiB. Each terminal Update carries the Result ID. The `result`
read uses a Session ID and Command ID and returns the saved Signal. A
successful read is stable across retries and server restarts.

## Typed IDs

`Jido.Seigyo.ID` generates and validates lower-case UUID version 7 IDs with a
type prefix.

| Kind | Prefix |
| --- | --- |
| Session | `ses_` |
| Command | `cmd_` |
| Workspace | `ws_` |
| Mutation | `mut_` |
| Attachment | `att_` |
| Result | `res_` |
| Artifact | `art_` |
| Actor | `act_` |
| Actor instance | `ain_` |

The ID type does not grant access. The server uses its trusted caller context
for each authorization decision.

## Limits and portable values

For use outside the umbrella, see the [standalone consumer](examples/standalone/README.md).

Client connections default to 128 pending calls, 64 watched Sessions, and 256
queued Updates per Session in acknowledged mode. Use `max_pending_requests`,
`max_watched_sessions`, and `max_pending_updates` to configure them. The allowed
maxima are 1,024, 100, and 1,000. Call overflow returns `too_large` before
transmission; Update overflow requires replay. After 4,096 diagnostic entries,
optional Progress stops for that connection; saved Results and Updates remain
available. See the [output and diagnostic rules](../../docs/seigyo/outputs.md).

The schemas apply byte and collection limits before the server uses input.
Important limits include:

| Value | Limit |
| --- | ---: |
| Command text | 8,192 bytes |
| Progress or reasoning text | 16,384 bytes |
| History text | 4,000 bytes |
| Session instructions | 16,384 bytes |
| Result Markdown block | 32,768 bytes |
| Aggregate Result blocks | 262,144 bytes |
| Workspace patch | 65,536 bytes |
| Decoded Attachment chunk | 65,536 bytes |
| Complete Attachment | 104,857,600 bytes |
| JSON integer | 9,007,199,254,740,991 maximum |

Portable value trees accept JSON scalars, lists, and string-keyed maps. One
tree has a 16 KiB value-cost budget, at most four container levels, at most 32
keys in one map, and at most 64 items in one list. Floating-point numbers,
atoms, PIDs, references, functions, and executable terms are not portable
protocol data.

## Errors

`Jido.Seigyo.Error` is a Splode error with safe client data:

```json
{
  "version": 1,
  "code": "invalid_field",
  "field": "text"
}
```

The stable codes are `invalid_field`, `invalid_id`, `unsupported_version`,
`too_large`, `conflict`, `not_found`, `gap`, and `unavailable`. A
`Failure` Signal carries this map for an operation failure. A valid Command
that the server declines uses a rejected `Receipt` instead.

## Use the schemas

Create a typed Signal and validate its protocol data:

```elixir
alias Jido.Seigyo.{ID, SessionOpen}

session_id = ID.generate(:session)

{:ok, signal} =
  SessionOpen.new(%{
    "version" => 1,
    "session_id" => session_id,
    "workspace_id" => nil
  })

{:ok, ^signal} = Jido.Seigyo.validate(signal)
```

Read the exact current endpoint catalog:

```elixir
capabilities = Jido.Seigyo.capabilities("local-user")

capabilities["operations"]
capabilities["request_signal_types"]
capabilities["result_signal_types"]
capabilities["push_signal_types"]
capabilities["update_event_types"]
```

Read the data-only draft catalog separately:

```elixir
Jido.Seigyo.draft_operations()
Jido.Seigyo.draft_request_signal_types()
Jido.Seigyo.draft_result_signal_types()
Jido.Seigyo.draft_push_signal_types()
```

## Protocol documents

The full protocol documents are in
[`docs/seigyo`](../../docs/seigyo/README.md). Use these main references:

- [model and ownership](../../docs/seigyo/model.md);
- [Signal shapes](../../docs/seigyo/signals.md);
- [delivery and recovery](../../docs/seigyo/delivery.md);
- [wire rules](../../docs/seigyo/wire.md); and
- [acceptance proof](../../docs/seigyo/conformance.md).

## Checks

Run these checks from this application directory:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix test --cover
```

The coverage command has a 100% threshold and writes an HTML report to
`cover/`.
