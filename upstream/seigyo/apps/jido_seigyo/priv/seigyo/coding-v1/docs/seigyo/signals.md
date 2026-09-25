# Seigyo Protocol: Signal shapes

## Signal schema catalog

This document gives current local version 1 shapes and draft remote shapes.
**Current** means the server advertises and uses the shape. **Draft** means a
closed data schema exists in `jido_seigyo`, but no server operation advertises
or handles it. **Proposed** means no data schema is fixed. A remote release
must publish a version and capability manifest that names every accepted
operation, emitted type, and Update variant. A draft shape must pass its
server policy, delivery, and acceptance gates before it becomes current.

## Notation and common rules

The shapes below use this notation:

- Every field is required unless its name ends in `?`.
- `| null` permits JSON `null`. An optional field may be absent. These are
  different rules.
- A number written as `integer >= 0` is a JSON integer, not a float. Every
  Seigyo Protocol integer is at most 9,007,199,254,740,991 so a JSON client
  can read it exactly. Current Signal schemas and WebSocket read arguments
  enforce this cap.
- A quoted value is a literal. `A | B` lists allowed values.
- Each `data` object is closed: it has no fields beyond those shown. This is
  true for current Jido Code Signals, including nested `View` content and all
  ten current `Update` payload variants.

| Name | Shape |
| --- | --- |
| `SessionID` | `"ses_"` followed by a lower case UUID version 7 |
| `CommandID` | `"cmd_"` followed by a lower case UUID version 7 |
| `WorkspaceID` | `"ws_"` followed by a lower case UUID version 7 |
| `MutationID` | `"mut_"` followed by a lower case UUID version 7 |
| `AttachmentID` | `"att_"` followed by a lower case UUID version 7 |
| `ResultID` | `"res_"` followed by a lower case UUID version 7 |
| `ArtifactID` | `"art_"` followed by a lower case UUID version 7 |
| `Sequence` | Integer at least 1, ordered within one Session |
| `Cursor` | Integer at least 0; 0 means no Update has been applied |
| `Revision` | Integer at least 0 |
| `Text` | Valid UTF-8, at most 8,192 bytes, and not blank after trim |
| `ModelID` | Valid UTF-8, 1 to 256 bytes, no control character, not blank after trim |
| `Name` | At most 64 bytes; matches `[a-z][a-z0-9_]*` |

Current portable maps contain JSON scalars, arrays, and string-keyed objects.
One value tree has a 16 KiB budget, at most four container levels, at most 32
keys in one object, and at most 64 items in one array. One string has at most
8 KiB. Integers stay within plus or minus 9,007,199,254,740,991. Floating
point numbers are not portable map values. `Progress` text and thinking use
a separate 16,384 byte limit. The portable tree budget applies to each
`View.content` or `Update.payload`, not to a whole `UpdatesPage`.

The current local 16 KiB check is a value cost, not encoded JSON length.
Count each object's or array's own cost as 1 byte; add each object key's
UTF-8 byte length; add each string value's UTF-8 byte length; count an
integer as 8 bytes and `null` or a boolean as 1 byte. Object keys must be
valid UTF-8 and 1 through 64 bytes. The root container is depth 0; a
container is allowed only at depth 0 through 3. Values inside a depth 3
container can be scalars. The remote frame and page byte caps are separate
checks on encoded JSON. A remote release must either adopt this cost rule
or version a replacement and publish boundary fixtures.

The first remote profile must project every Signal to exactly this Jido
CloudEvents JSON object:

```text
{
  "specversion": "1.0",
  "id": UUID7,
  "source": "/jido/code/client" | "/jido/code/server",
  "type": one type from the catalog below,
  "data": one data object from the matching section below
}
```

The sender generates a lower case UUID version 7 envelope `id`. Jido Signal
generates it for local Elixir Signals; an independent client generates its
own. The client Signal modules default to
`/jido/code/client`; server Signal modules default to `/jido/code/server`. These
sources identify the logical sender role. The `jido.client.*` type prefix
identifies this protocol and does not need to match `source`. Neither field
authenticates the caller. Current local Signals and the Jido codec can carry
`subject`, `time`, or other CloudEvents context fields. The remote adapter
emits only the five attributes shown above and rejects extra input
attributes before Seigyo validation. `data_base64` is not a Jido Code client payload.
The remote decoder must validate the envelope, then the Jido Code type and data.
It must not make atoms from any received string. A remote proof must also
enforce the envelope ID and source rules; current `Jido.Seigyo.validate/1` checks
the type and data only.

The envelope `id` identifies one Signal instance. `Command.data.id` is the
retry key for work. A transport request reference is only for one call or
socket reply. These three IDs have different uses.
The Store saves Update events, not their Signal envelope IDs. A replayed
Update can have a new envelope ID. Its `session_id`, `sequence`, and data
still identify and describe the same saved event.

## Type catalog

**SEIGYO-WIRE-001:** Every Jido Code client Signal type starts with
`jido.client.`. The next segment is the protocol version. The remaining
segments name one closed message. The
`source` attribute remains a separate CloudEvents field; it does not set the
type namespace or caller identity. A remote adapter checks that a client
request has source `/jido/code/client` and a server result has source
`/jido/code/server`, but it trusts only its connection context for identity.

| Direction | Signal | Type | State |
| --- | --- | --- | --- |
| Client to Server | `SessionOpen` | `jido.client.v1.session.open` | Current |
| Server to client | `SessionOpened` | `jido.client.v1.session.opened` | Current |
| Client to Server | `Command` | `jido.client.v1.command` | Current |
| Server to client | `Receipt` | `jido.client.v1.receipt` | Current |
| Server to client | `View` | `jido.client.v1.view` | Current |
| Server to client | `UpdatesPage` | `jido.client.v1.updates.page` | Current |
| Server to client | `HistoryPage` | `jido.client.v1.history.page` | Current |
| Server to client | `Update` | `jido.client.v1.update` | Current |
| Server to client | `Progress` | `jido.client.v1.progress` | Current |
| Server to client | `ResyncRequired` | `jido.client.v1.resync.required` | Current |
| Server to client | `Trace` | `jido.client.v1.trace` | Current |
| Server to client | `WorkspaceChanges` | `jido.client.v1.workspace.changes` | Current |
| Server to client | `Workspaces` | `jido.client.v1.workspaces` | Current |
| Client to Server | `WorkspaceConfigure` | `jido.client.v1.workspace.configure` | Current |
| Server to client | `WorkspaceConfigured` | `jido.client.v1.workspace.configured` | Current |
| Server to client | `Failure` | `jido.client.v1.failure` | Current |
| Server to client | `SessionConfiguration` | `jido.client.v1.session.configuration` | Current |
| Server to client | `SessionConfigurationsPage` | `jido.client.v1.session.configurations.page` | Current |
| Client to Server | `SessionConfigure` | `jido.client.v1.session.configure` | Current |
| Server to client | `SessionConfigured` | `jido.client.v1.session.configured` | Current |
| Client to Server | `SessionFork` | `jido.client.v1.session.fork` | Current |
| Server to client | `SessionForked` | `jido.client.v1.session.forked` | Current |
| Client to Server | `TurnSubmit` | `jido.client.v1.turn.submit` | Current |
| Server to client | `TurnReceipt` | `jido.client.v1.turn.receipt` | Current |
| Client to Server | `TurnSteer` | `jido.client.v1.turn.steer` | Current |
| Client to Server | `TurnCancel` | `jido.client.v1.turn.cancel` | Current |
| Server to client | `TurnControlled` | `jido.client.v1.turn.controlled` | Current |
| Server to client | `Result` | `jido.client.v1.result` | Current |
| Client to Server | `AttachmentBegin` | `jido.client.v1.attachment.begin` | Current |
| Client to Server | `AttachmentChunk` | `jido.client.v1.attachment.chunk` | Current |
| Client to Server | `AttachmentCommit` | `jido.client.v1.attachment.commit` | Current |
| Server to client | `Attachment` | `jido.client.v1.attachment` | Current |
| Server to client | `ContextCompacted` | `jido.client.v1.context.compacted` | Draft |

Connection join and leave are transport controls. They are not durable
Commands and do not need a Jido Code Signal in version 1. Every v1 item pushed on
a live connection is an `Update`, `Progress`, or `ResyncRequired` Signal.
`Failure` is a reply to one call. An Updates read returns one `UpdatesPage`
Signal. Current native and remote reads return ordered Update data in that
page. Live delivery uses full `Update` Signals. The current Seigyo Protocol
WebSocket publishes `watch_progress` and `watch_updates` as transport controls.
They are not durable operations.
The typed read arguments are in the [operations table](model.md#operations-and-results).

## Coding Session evolution

Items marked Current are in `Jido.Seigyo.capabilities/1`. A client must not use
a Draft item until discovery advertises its operation and Signal type. Server
policy controls authorization, lifecycle, revision changes, queue order, and
execution placement.

`MutationID` is the retry identity for a Session mutation that does not
create a coding turn. `CommandID` stays the retry identity for one queued or
active coding turn. Steering and cancellation therefore use a Mutation ID
and name a target Command ID.

### Session configuration

One configuration snapshot contains these closed fields:

```text
SessionConfig = {
  "version": 1,
  "revision": Revision,
  "state": "effective" | "pending",
  "profile": "coding",
  "digest": SHA256,
  "model": {
    "id": ModelID,
    "reasoning_level": "none" | "minimal" | "low" | "medium" |
                       "high" | "xhigh" | "max" | "ultra"
  },
  "context": {
    "mode": "managed" | "full" | "rolling",
    "target_tokens": integer >= 1024,
    "preserve_recent_turns": integer from 0 through 1000,
    "compaction_policy": "none" | "summarize"
  },
  "skills": [{"id": string, "version": string | null,
               "digest": SHA256 | null}],
  "plugins": [{"id": string, "version": string | null,
                "capabilities": [Name]}],
  "tool_profile": {"id": string, "version": string, "digest": SHA256},
  "execution": {
    "workspace_id": WorkspaceID,
    "target_id": TargetID,
    "isolation": "trusted_local" | "container" | "vm" | "remote",
    "network": "denied" | "restricted" | "allowed",
    "sandbox": {"id": SandboxID, "profile": string} | null
  },
  "instructions": string
}
```

Instructions have a 16,384 byte limit. A Skill or Plugin reference has a
256 byte limit. The optional Skill digest is a lower case SHA-256 value.
The execution object gives a requested policy. It does not expose a host,
path, process, container, or credential. A Workspace is the stable logical
code tree. An execution placement is the private environment that operates on
that tree. A move to another placement does not create another Workspace. A
copy that can diverge must use another Workspace ID.

The current `configuration` read returns:

```text
SessionConfiguration.data = {
  "version": 1,
  "session_id": SessionID,
  "effective": SessionConfig with state "effective",
  "pending": SessionConfig with state "pending" | null
}
```

The current `configuration_history` read takes a Session ID, a nullable
exclusive `after_revision`, and a limit from 1 through 100. It returns:

```text
SessionConfigurationsPage.data = {
  "version": 1,
  "session_id": SessionID,
  "oldest_revision": Revision,
  "after_revision": Revision | null,
  "configurations": [SessionConfig],
  "next_cursor": Revision | null
}
```

Configurations are ascending and contiguous. A null cursor starts at the
oldest saved revision. A cursor below the retained floor fails with `gap`.
Each full configuration digest is the lower case SHA-256 of canonical compact
JSON for its semantic fields. Revision, state, and digest are not digest
inputs. A patch cannot set the server-owned tool profile.

A pending revision is greater than the effective revision. A configuration
change uses a nonempty patch with any complete configuration field:

```text
SessionConfigure.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "expected_revision": Revision,
  "apply": "when_idle" | "next_command",
  "patch": nonempty partial SessionConfig fields
}

SessionConfigured.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "sequence": Sequence,
  "disposition": "applied" | "pending" | "duplicate",
  "previous_revision": Revision,
  "effective_from": "current" | "next_command",
  "config": SessionConfig
}
```

The returned configuration revision is the previous revision plus one.
`applied` has effective state and starts at `current`. `pending` has pending
state and starts at `next_command`. `duplicate` returns the original saved
result. The sequence identifies the saved configuration fact. A model change
is a critical saved fact because later output can change with the model. The
server must pin a configuration revision, model ID, and context revision to a
Command before execution. It must not change an active Command when a later
configuration request arrives.

### Queued turns and active control

```text
TurnSubmit.data = {
  "version": 1,
  "command_id": CommandID,
  "session_id": SessionID,
  "text": Text,
  "attachment_ids": [AttachmentID],
  "delivery": "enqueue" | "reject_if_busy",
  "expected_config_revision": Revision | null
}

TurnReceipt.data = {
  "version": 1,
  "command_id": CommandID,
  "session_id": SessionID,
  "disposition": "accepted" | "duplicate" | "rejected",
  "state": "active" | "queued" | null,
  "session_revision": Revision | null,
  "sequence": Sequence | null,
  "error": ErrorData | null
}

TurnSteer.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "target_command_id": CommandID,
  "text": Text,
  "attachment_ids": [AttachmentID]
}

TurnCancel.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "target_command_id": CommandID,
  "reason": string | null
}

TurnControlled.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "target_command_id": CommandID,
  "action": "steer" | "cancel",
  "disposition": "applied" | "duplicate",
  "sequence": Sequence
}
```

One submit has at most 32 distinct Attachment IDs. Submit creates a turn.
An accepted or duplicate `TurnReceipt` has an initial state, Session revision,
saved sequence, and no error. A rejected receipt has no state or saved
position and has an error.
Steer changes one active turn if the server can still apply it. It never
creates a queued turn. Cancel targets one active or queued turn. Retry with
the same Mutation ID must return the first control result and must not apply
the control twice. An applied or duplicate `TurnControlled` value has the
original saved sequence. A rejected control returns `Failure`. The closed
durable queue variants are current and have replay proof.

### Forks and side chats

```text
SessionFork.data = {
  "version": 1,
  "mutation_id": MutationID,
  "source_session_id": SessionID,
  "session_id": SessionID,
  "at_event_cursor": Cursor,
  "relation": "fork" | "side_chat",
  "config_policy": "inherit" | "override",
  "workspace_policy": "snapshot" | "shared_read_only" | "shared_mutable",
  "config_patch": partial SessionConfig fields | null
}

SessionForked.data = {
  "version": 1,
  "mutation_id": MutationID,
  "session_id": SessionID,
  "root_session_id": SessionID,
  "parent_session_id": SessionID,
  "fork_event_cursor": Cursor,
  "relation": "fork" | "side_chat",
  "workspace_id": WorkspaceID,
  "config_revision": Revision,
  "context_revision": Revision
}
```

`inherit` requires a null patch. `override` requires a nonnull patch. The
child starts from the current committed parent cursor. Version 1 rejects an
older cursor because historical configuration and Workspace checkpoints are
not stored. The child then has its own event,
configuration, and context revisions. The server checks which Workspace
policies each caller and provider can use. The coding defaults are an isolated
managed snapshot for a fork and shared read-only access for a side chat.
An exact Mutation ID retry returns the first child. Different request data
with the same Mutation ID is a conflict.

### Attachments

An Attachment is immutable content. A begin request declares its ID, Session,
name, media type, byte size, SHA-256 value, and purpose. The size is from 1
through 104,857,600 bytes. `purpose` is `context`, `image`, `patch`, or
`workspace_import`. A chunk contains an Attachment ID, zero-based index, and
nonempty strict base64 data. Decoded chunk data has at most 65,536 bytes. Commit names
the Attachment ID. The server result repeats the safe metadata and reports:

```text
AttachmentBegin.data = {
  "version": 1,
  "attachment_id": AttachmentID,
  "session_id": SessionID,
  "name": string,
  "media_type": string,
  "size": integer,
  "sha256": SHA256,
  "purpose": "context" | "image" | "patch" | "workspace_import"
}

AttachmentChunk.data = {
  "version": 1,
  "attachment_id": AttachmentID,
  "index": integer >= 0,
  "data": base64 string
}

AttachmentCommit.data = {
  "version": 1,
  "attachment_id": AttachmentID
}

Attachment.data = {
  "version": 1,
  "attachment_id": AttachmentID,
  "session_id": SessionID,
  "state": "uploading" | "ready" | "rejected",
  "name": string,
  "media_type": string,
  "size": integer,
  "sha256": SHA256,
  "uploaded_bytes": integer,
  "next_chunk_index": integer,
  "error": ErrorData | null
}
```

Only a ready Attachment can be used by a turn. Commit must verify the declared
size and SHA-256 value. The server controls retention, authorization, safe
media handling, and fork reuse. No Attachment field contains a local path.
With a durable storage profile, the server saves each accepted begin, chunk,
and commit state before it sends the reply. A restart recovers the exact
`uploaded_bytes` and `next_chunk_index` values. A client can retry the last
accepted chunk and continue the upload. Ready and rejected Attachments also
survive a restart. The memory storage profile makes no restart guarantee.

### Normalized results and context changes

`Result` is the client result of one coding turn. Its completion scope is
`execution`: `status: "completed"` means that execution ended normally and
produced this Result. It does not prove that the requested change is correct,
that verification passed, that a user approved it, or that it was published.
It has a Result ID, Session ID, Command ID, pinned model ID, configuration
revision, context revision, measured usage, a bounded reasoning policy, and at
most 50 ordered result blocks. A block is one of `markdown`, `attachment`,
`artifact`, `workspace_changes`, or `citation`. Markdown has a 32,768 byte
limit. The reasoning visibility is `hidden` with a null summary or `summary`
with bounded text. Completed and cancelled results have no error. Failed and
uncertain results have an ErrorData value.

```text
Result.data = {
  "version": 1,
  "result_id": ResultID,
  "session_id": SessionID,
  "command_id": CommandID,
  "completion": "execution",
  "status": "completed" | "failed" | "cancelled" | "uncertain",
  "config_revision": Revision,
  "config_digest": SHA256,
  "tool_profile": {"id": string, "version": string, "digest": SHA256},
  "context_revision": Revision,
  "model_id": ModelID | null,
  "blocks": [ResultBlock],
  "usage": {
    "measurement": "reported" | "estimated" | "mixed" | "unavailable",
    "input_tokens": integer >= 0 | null,
    "output_tokens": integer >= 0 | null,
    "reasoning_tokens": integer >= 0 | null,
    "cache_read_tokens": integer >= 0 | null,
    "cache_write_tokens": integer >= 0 | null,
    "model_calls": integer >= 0,
    "delegated_runs": integer >= 0
  },
  "reasoning": {
    "visibility": "hidden" | "summary",
    "summary": string | null,
    "truncated": boolean
  },
  "error": ErrorData | null
}

ResultBlock =
  {"type":"markdown", "text":string, "truncated":boolean} |
  {"type":"attachment", "attachment_id":AttachmentID} |
  {"type":"artifact", "artifact_id":ArtifactID,
   "name":string, "media_type":string} |
  {"type":"workspace_changes", "workspace_id":WorkspaceID} |
  {"type":"citation", "uri":string, "title":string}
```

`reported` and `estimated` require every token field. `mixed` means that some
token fields are known and some are unavailable, or that more than one
measurement source was used. `unavailable` requires every token field to be
null. A missing provider value is never changed to zero. `model_calls` and
`delegated_runs` are server-owned counts and are always integers.

The `result` read takes a Session ID and Command ID. It returns the saved
`Result` for a terminal turn. The server saves the Result in the same Store
settlement as the terminal Command state, so repeated reads and server
restarts return the same value. It returns `Failure` when the Session or
Command does not exist or the caller has no access. A nonterminal turn returns
`Failure` with code `unavailable` and field `result`, so a client can use a
bounded retry. Reading a Result has no admission or mutation effect.

The server can use any internal subagent graph. The client sees the normalized
Result and aggregate `delegated_runs`; it does not receive internal process,
task, or Agent references. Trace can later give bounded tool and delegation
evidence without exposing internal topology.

`ContextCompacted` records the old and new context revisions, source event
range, preserved recent turns, estimated tokens before and after, reason, and
saved Session sequence. The new revision is exactly one above the old
revision. Its source range ends before the compaction fact, and its token
estimate cannot grow. Compaction creates a new model context. It does not
rewrite Session history.

```text
ContextCompacted.data = {
  "version": 1,
  "session_id": SessionID,
  "sequence": Sequence,
  "config_revision": Revision,
  "previous_context_revision": Revision,
  "context_revision": Revision,
  "source_from_sequence": Cursor,
  "source_to_sequence": Cursor,
  "preserved_turns": integer >= 0,
  "estimated_tokens_before": integer >= 0,
  "estimated_tokens_after": integer >= 0,
  "reason": "threshold" | "model_change" | "client_request" | "recovery"
}
```

`SessionConfigured` and the standalone `ContextCompacted` shape contain the
same durable sequence facts that coding v1 projects through the closed
`session_configured` and `context_compacted` Update variants. The standalone
compaction push type is not advertised. A client recovers both facts through
Updates. WebSocket acceptance tests prove replay after a client disconnect.

### Proposed collaboration Signals

These types are reserved design names, not supported v1 messages. An ADR must
fix their version, closed Zoi data schemas, sizes, and failure cases before a
client sends them. The current local modules use one Seigyo file per Signal;
future public messages need versioned schemas, independent of file layout. The
Session document authority handles them through Server. A transport only
encodes and routes them.

| Direction | Signal | Data needed | Result or delivery |
| --- | --- | --- | --- |
| Client to Server | `DocumentDelta` | Document ID, stable operation ID, base document revision, text delta | `DocumentDeltaAccepted` or `Failure` |
| Server to client | `DocumentDeltaAccepted` | Document ID, operation ID, accepted revision, transformed delta | Reply; duplicate returns original result |
| Server to client | `DocumentDeltaApplied` | Document ID, operation ID, author User ID, accepted revision, transformed delta | Live fanout to authorized Clients |
| Server to client | `DocumentSnapshot` | Document ID, revision, bounded text | Result of an authorized snapshot read |
| Server to client | `DocumentResyncRequired` | Document ID, reason | Live hint or stale base result; get a snapshot |
| Server to client | `PresenceSnapshot` | Session ID, bounded online User summaries | Result of attach or presence read |
| Server to client | `PresenceChanged` | Session ID, User summary, online state | Temporary live hint; refresh from snapshot |

Member grant changes need an authenticated mutation Signal with a stable
operation ID and a durable audit event. The first collaboration ADR must
decide its exact roles, owner transfer rule, and retry shape. Command author
fields and member events need a new contract version or negotiated capability;
they cannot be added as unknown keys to current closed v1 Signals. Text delta
operations need a closed grammar with retain, insert, and delete components,
valid UTF-8 inserts, UTF-16 offsets, bounded operation count and byte size,
and a deterministic transform rule. The OT ADR must fix these values before
the reserved names become a wire contract.

## Session open

**`SessionOpen.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "workspace_id": WorkspaceID | null
}
```

`null` selects the configured default Workspace for a new Session. If the
Session ID already exists, Server returns it when the requested Workspace ID
is `null` or matches its saved Workspace ID. A different Workspace ID is a
conflict. The client chooses the Session ID before its first open attempt so
it can retry a lost reply.

**`SessionOpened.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "workspace_id": WorkspaceID,
  "protocol_version": 1,
  "protocol_profile": "coding"
}
```

## Command admission

**`Command.data` (current):**

```text
{
  "version": 1,
  "id": CommandID,
  "session_id": SessionID,
  "kind": "submit_text",
  "input": {
    "text": Text,
    "model"?: ModelID
  }
}
```

The current native call also accepts `expected_revision` outside the Signal.
This option stays internal in client version 1. A later client precondition
needs a new Command contract and a saved retry rule. A retry sends the same
Command data. The same command ID with another kind or input is a conflict.
`cancel` and `close` are not supported `kind` values. Before first remote
access, Server must save the effective model ID in the CommandRecord even
when `input.model` is absent. This saved value does not change retry identity.

**`Receipt.data` (current):**

```text
{
  "version": 1,
  "command_id": CommandID,
  "session_id": SessionID,
  "disposition": "accepted" | "duplicate" | "rejected",
  "session_revision": Revision | null,
  "sequence": Sequence | null,
  "error": ErrorData | null
}
```

For `accepted` or `duplicate`, both numbers are present and `error` is
`null`. The sequence is the saved `command_accepted` Update position. For
`rejected`, both numbers are `null` and `error` is present. A Receipt reports
admission, not the model result. A rejected Receipt does not reserve work.

## Bounded reads

**`View.data` (current top level):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "session_revision": Revision,
  "agent_revision": Revision | null,
  "event_cursor": Cursor,
  "lifecycle": "open" | "closing" | "closed",
  "content": ViewContent
}
```

The current Server builds this `ViewContent` shape. Its Zoi schema is closed,
and the shared client converts each nested value to a typed Zoi struct. The
View must meet the coherent cut rule above. A newer live Agent snapshot is not
enough when it contains a result that the Store has not linked to the View
cursor.

```text
ViewContent = {
  "last_result": string | null,
  "last_result_command_id": CommandID | null,
  "messages": [Message],
  "messages_truncated": boolean,
  "workspace": WorkspaceSummary
}

Message = {
  "command_id": CommandID,
  "role": "user" | "assistant",
  "text": string
}

WorkspaceSummary = {
  "id": WorkspaceID,
  "name": string,
  "ownership": "borrowed" | "managed" | "unknown",
  "mode": "shared" | "exclusive" | "unknown",
  "status": "ready" | "unavailable"
}
```

Current View projection includes at most 30 messages and at most 4,000 bytes
of text in one message. It has an overall portable value budget of 16 KiB.
Each message carries its Command ID for the same stable Seigyo Protocol join
as a History entry. `messages_truncated` is true when the View omits an older
message or part of a message. The client reads History when it needs the full
available transcript.
`last_result_command_id` identifies the Command that produced `last_result`.
Both values are null or both values are present.
A later failed Command does not replace this pair. Its failed Update, Trace,
and recent outcome identify that Command, while the pair stays on the latest
successful assistant result.
`last_result` has at most 1,000 characters. Current local Workspaces report
`borrowed` and `shared`; `managed` and `exclusive` are reserved for later
providers.
Neither View nor WorkspaceSummary contains a root path, PID, Agent reference,
credential, or full Thread.

The current Server includes these fields in the closed `ViewContent` schema.
It must keep these fields and the message page inside the current 16 KiB View
content budget:

```text
"active_command": {
  "command_id": CommandID,
  "state": "accepted" | "dispatched"
} | null

"recent_outcomes": [
  {
    "command_id": CommandID,
    "state": "completed" | "failed" | "cancelled" | "uncertain",
    "sequence": Sequence
  }
]
```

`recent_outcomes` has at most 10 items in descending outcome sequence order.
It is a current summary, not the full event log. A client can read a Trace
for a command ID when it needs more detail.

An uncertain outcome with no proven Agent revision clears the View's
`agent_revision`. Until reconciliation supplies new proof, the View reports
the durable uncertain outcome but returns `null` for `last_result` and an
empty `messages` list. This prevents stale Agent content from appearing as a
completed result.

An Updates read takes a Session ID, `after_sequence: Cursor`, and `limit`
from 1 through 100. These are typed operation arguments, not Signal data.

**`UpdatesPage.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "after_sequence": Cursor,
  "updates": [UpdateData],
  "next_cursor": Cursor | null
}
```

`UpdateData` is the selected remote closed form of `Update.data` used by a
live Update Signal. The current local schema is still open. The page has one
Signal envelope; its items need no second envelope
ID or type. The page holds at most the requested limit and at most 256 KiB
when encoded as JSON. It can stop early at the byte limit. Each item must
pass the selected Update variant schema, match the page `session_id`, and have
ascending contiguous sequences. `after_sequence` must equal the request
cursor, and the first item must be the next sequence. `next_cursor` is the last
included sequence when more saved Updates remain. It is `null` when the
page reaches the current end. A page must include at least one Update when
one is available after the cursor. A client advances its own cursor to the
last Update it applied. Live delivery sends a full Update Signal without the
page wrapper. Its envelope ID can differ from a replayed copy of the event.

A History read takes a Session ID, `after_sequence: Cursor`, and `limit` from
1 through 100. History sequences identify ordered projected messages. They
are separate from saved Update sequences.

**`HistoryPage.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "entries": [HistoryEntry],
  "next_cursor": Cursor | null
}

HistoryEntry = {
  "sequence": Sequence,
  "command_id": CommandID,
  "role": "user" | "assistant",
  "text": string,
  "truncated": boolean
}
```

One history text has at most 4,000 bytes. Tool-only and empty messages do not
create entries. Each entry carries the Command ID that created its turn, so a
Seigyo Protocol client can join History to its Receipt, Updates, and Trace. A
page has at most 100 entries. `next_cursor` is the last included history
sequence when more entries remain.
A failed request with no committed conversation message has no History entry;
its durable Update and Trace still carry its Command ID.

A Workspace Changes read takes one Session ID. It reads the Workspace bound
to that Session. It never returns the physical Workspace path.

**`WorkspaceChanges.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "workspace_id": WorkspaceID,
  "base_revision": string | null,
  "clean": boolean,
  "files": [WorkspaceChange],
  "patch": string,
  "truncated": boolean
}

WorkspaceChange = {
  "path": string,
  "status": "added" | "modified" | "deleted" | "renamed" |
            "copied" | "untracked" | "conflicted"
}
```

The result has at most 500 file entries in ascending path order. A path has at
most 4,096 bytes and no control character. The patch has at most 65,536 bytes.
`truncated` is true when the status or patch exceeds its bound.
`base_revision` is null for an unborn Git Workspace.

Trace read arguments are a Session ID and Command ID. They are not Signal
data.

The `workspaces` operation has empty arguments. Its current v1 form returns
one authorized, bounded snapshot of local Workspaces. A later provider with no
host file path needs another versioned item shape.

**`Workspaces.data` (current):**

```text
{
  "version": 1,
  "workspaces": [Workspace]
}

Workspace = {
  "id": WorkspaceID,
  "name": string,
  "file_path": absolute string,
  "runtime_path": canonical absolute string,
  "ownership": "borrowed" | "managed",
  "mode": "shared" | "isolated",
  "status": "ready" | "unavailable",
  "version": positive integer
}
```

The list has at most 256 items. It is sorted by case-insensitive name and then
Workspace ID. One server catalog call produces the snapshot. This first list
is not paged. The authenticated principal sees only its Workspaces.

`file_path` is the configured host path for the local provider.
`runtime_path` is the independent path that a Sandbox runtime uses for the
same Workspace binding. The runtime path does not name a host directory and
does not select a Sandbox. These administrative fields do not appear in
Session View, Trace, Result, or Workspace Changes.

**`WorkspaceConfigure.data` (current):**

```text
{
  "version": 1,
  "mutation_id": MutationID,
  "workspace_id": WorkspaceID,
  "expected_version": positive integer | null,
  "name": string,
  "file_path": absolute string,
  "runtime_path": canonical absolute string
}
```

Use a null expected version to create the named Workspace ID. Use the current
version to change an existing Workspace. An existing Workspace keeps its file
path and provider identity. A different file path conflicts. A name or runtime
path change increments the Workspace version. The same desired values return
`unchanged` without another increment. An active Workspace lease blocks a
change. The server takes the owner from the authenticated connection, not from
Signal data.

**`WorkspaceConfigured.data` (current):**

```text
{
  "version": 1,
  "mutation_id": MutationID,
  "disposition": "created" | "updated" | "unchanged",
  "workspace": Workspace
}
```

Session listing still has no assigned client Signal type or wire shape. The
[Work proposal](work.md) describes the desired authorized Session list. A
Session listing ADR must fix order, cursor, concurrent-change behavior, item
bounds, safe fields, and version before adding a result type.

## Saved Updates and live Progress

**`Update.data` (current):**

```text
UpdateData = {
  "version": 1,
  "session_id": SessionID,
  "kind": "event",
  "sequence": Sequence,
  "event_type": "command_accepted" | "turn_started" |
                "turn_steered" | "turn_cancel_requested" |
                "command_completed" | "command_failed" |
                "command_cancelled" | "command_uncertain" |
                "session_configured" | "context_compacted",
  "command_id": CommandID | null,
  "payload": one closed object selected by event_type
}
```

The ten rows below are the full coding v1 Seigyo Protocol union.
`event_type` selects exactly one payload shape. No unknown event, extra payload
key, invalid Command ID, or reserved gap value can pass Signal validation.
Only Session configuration and context compaction have a null Command ID.
The Store can retain a broader internal EventRecord. Server must project a
retained record into this union before it creates an Update. If it cannot,
the whole read fails with `unavailable` on `updates`; it does not skip the
record or advance the cursor.

| `event_type` | `payload` | State |
| --- | --- | --- |
| `command_accepted` | `kind` is `submit_text`; `state` is `active` or `queued` | Current coding v1 |
| `turn_started` | `{}` | Current coding v1 |
| `turn_steered` | `{"mutation_id":MutationID}` | Current coding v1 |
| `turn_cancel_requested` | `{"mutation_id":MutationID}` | Current coding v1 |
| `command_completed` | `{"result_id":ResultID}` | Current coding v1 |
| `command_failed` | `reason` is `execution_failed`, `dispatch_unavailable`, or `admission_rejected`; includes `result_id` | Current coding v1 |
| `command_cancelled` | `{"mutation_id":MutationID|null,"result_id":ResultID}` | Current coding v1 |
| `command_uncertain` | `reason` is `agent_state_unknown` or `server_restarted`; includes `result_id` | Current coding v1 |
| `session_configured` | Mutation ID, old and new revisions, effective point, and applied or pending disposition | Current coding v1 |
| `context_compacted` | Configuration and context revisions, source range, preserved turns, token estimates, and reason | Current coding v1 |

A provider failure can retain an internal `request_id`. Server replaces it
with the safe `execution_failed` reason. A client reads `Trace` by Command ID
for detail. Do not infer success from a Receipt or Progress. An Updates read
that reaches an event outside this union fails without returning a partial
page.

The old reserved `kind: "gap"` Update shape is not part of version 1 and is
rejected. A failed Updates read uses
`Failure` with code `gap` and the client gets a fresh View. A live buffer
gap uses `ResyncRequired` instead.

**`ResyncRequired.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID
}
```

This is a live hint, not a saved Update. It means that the adapter can no
longer promise ordered live delivery for this Session. The client reads
Updates after its own last applied sequence. If that read returns `gap`,
it reads a fresh View. It does not treat this Signal as a new event cursor.

**`Progress.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "command_id": CommandID,
  "sequence": integer >= 0,
  "iteration": integer >= 0,
  "phase": "working" | "thinking" | "writing" | "using_tools" | "finishing",
  "text": string,
  "truncated": boolean,
  "thinking": string,
  "thinking_truncated": boolean,
  "tools": [ToolSummary],
  "tools_truncated": boolean
}
```

`text` and `thinking` each have a 16,384 byte limit. `tools` has at most 24
items. `sequence` is a request event sequence, not a saved Update sequence.
Each Progress is a full replacement snapshot. It is not replayed.

The current coding WebSocket has an authorized `watch_progress` transport
control. The Seigyo Protocol capability manifest lists the Progress Signal in
`push_signal_types`. A successful watch sends full Progress Signals for that
Session. The remote coding profile always sends `thinking: ""` and
`thinking_truncated: false`. A client must not use the Progress `sequence` as
its durable Update cursor. It must read Updates after a connection loss or a
terminal result.

**`Trace.data` (current):**

```text
{
  "version": 1,
  "session_id": SessionID,
  "command_id": CommandID,
  "model_id": ModelID | null,
  "config_revision": Revision,
  "config_digest": SHA256,
  "tool_profile": {"id": string, "version": string, "digest": SHA256},
  "status": "accepted" | "dispatched" | "completed" | "failed" |
            "cancelled" | "uncertain",
  "failure_reason": string | null,
  "duration_ms": integer >= 0 | null,
  "model_calls": integer >= 0,
  "input_tokens": integer >= 0,
  "output_tokens": integer >= 0,
  "truncated": boolean,
  "tools": [ToolSummary],
  "thinking": string,
  "thinking_truncated": boolean
}

ToolSummary = {
  "id": string,
  "name": string,
  "status": "running" | "ok" | "error" | "completed" | "unknown",
  "duration_ms": integer >= 0 | null,
  "truncated": boolean,
  "summary": string | null
}
```

`Trace.tools` has at most 100 items. Each tool ID and name has a Zoi length
limit of 128; a tool summary has a limit of 200. `failure_reason` has a limit
of 100. `thinking` has a 16,384 byte limit. `Trace` is a bounded view of
Agent request activity; it is not a second command log. These fields describe
the current Jido AI coding profile. A general agent does not have to supply
model calls, tokens, tools, or thinking. `model_id` is the effective model ID
saved before dispatch. It is null only for a legacy CommandRecord that was
saved before this Seigyo Protocol guarantee existed.
The configuration revision, digest, and tool profile identify the exact
server-owned execution contract pinned before admission.

The current coding WebSocket always sends `thinking: ""` and
`thinking_truncated: false` in Trace. The Seigyo Protocol client schema rejects
a remote Trace that contains reasoning text. This remote rule does not remove
reasoning from the local server projection.

## Failure shape

`ErrorData` is the current `Jido.Seigyo.Error.to_map/1` shape. A rejected
Receipt embeds it. The current `Failure` Signal uses it as its full data
object for a failed open, read, or transport request. `Failure` is a reply
to one call; its transport request reference supplies call correlation.

```text
ErrorData = {
  "version": 1,
  "code": "invalid_field" | "invalid_id" | "unsupported_version" |
          "too_large" | "conflict" | "not_found" | "gap" |
          "unavailable",
  "field": Name | null
}

Failure.data = ErrorData
```

The remote identity ADR must fix authentication and authorization error
codes and whether a denied lookup uses the same result as an absent
resource. Do not turn an authorization failure into a command Receipt: the
Server must reject it before command admission.
The current file Store can use `field: "store.capacity"`, which does not
match the current `Name` rule. Use a valid public field such as `"store"`
for that case, and test a full Store before remote access.
An invalid Signal also gets `Failure` before admission. A valid Command that
Server declines gets a rejected Receipt. A failed accepted command gets a
saved outcome Update. An uncertain Update remains unresolved.
The transport may add an HTTP status or socket reply status, but the Signal
error code has the same meaning on every path.

### Error release gate

Coding v1 fixes the current error codes, safe `field` names, and Phoenix
Channel reply status. The generated release bundle contains the stable error
map and an exact invalid-Session reply fixture. Focused wire tests cover
malformed frames, versions, IDs, shapes, types, and sizes. Acceptance covers
open and duplicate conflicts, busy and unavailable admission, absent reads,
cursor errors, and caller isolation. External authentication errors and a
stored event that the selected protocol cannot encode still need a public
release policy. HTTP is not a coding v1 transport. An error must not expose an
internal path or private resource data.
