# Generic message shapes

All messages use the [CloudEvents envelope](cloudevents.md). The names below are **draft DASP names**. They do not identify an existing released service.

Fields in each shape are required unless marked `?`. Optional and null are different. Core objects are closed, including the `error` and `profile` objects.

## Shared values {#dasp-msg-001}

Requirement group **DASP-MSG-001**.

| Name | Shape |
| --- | --- |
| ID | 1–128 ASCII letters, digits, dot, underscore, colon, or hyphen; opaque and case-sensitive |
| Actor ID | ID; resolved by the authorized host, never as a local process address |
| Cursor | Integer from 0 through 9,007,199,254,740,991 |
| Sequence | Cursor greater than 0 |
| Profile | `{ "id": absolute URI, "version": nonempty string }` |
| Name | 1–128 characters matching `[a-z][a-z0-9_.-]*` |
| Payload | JSON object, with its contents defined by the selected profile |
| Error | `{ "code": Name, "message": string, "retryable": boolean }` |

The host MUST reject new writes before sequence exhaustion; it cannot wrap or reset a cursor within an existing session.

## Catalog {#dasp-msg-002}

Requirement group **DASP-MSG-002**.

Each type starts with `dasp.v1.` followed by the operation name. Version 1 is a draft namespace until release.

| Type | Direction | Meaning |
| --- | --- | --- |
| `dasp.v1.session.open` | Client → host | Create or reopen a session |
| `dasp.v1.session.opened` | Host → client | Saved session identity |
| `dasp.v1.command` | Client → host | Issue application intent |
| `dasp.v1.receipt` | Host → client | Admission decision |
| `dasp.v1.update` | Host → client | Immutable saved fact |
| `dasp.v1.progress` | Host → client | Temporary activity |
| `dasp.v1.view.read` | Client → host | Read a coherent projection |
| `dasp.v1.view` | Host → client | Projection at a cursor |
| `dasp.v1.updates.read` | Client → host | Read saved events after a cursor |
| `dasp.v1.updates` | Host → client | Bounded page of saved events |
| `dasp.v1.outcome.read` | Client → host | Read command settlement |
| `dasp.v1.outcome` | Host → client | Known outcome or pending state |
| `dasp.v1.resync.required` | Host → client | Live delivery no longer complete |
| `dasp.v1.failure` | Host → client | Request failed at the protocol boundary |

The four [capability-discovery operations](capability-discovery.md#dasp-disc-004)
are setup-subprotocol operations. They are not core message types and do not
change this catalog. A binding MUST NOT encode them as another `dasp.v1.*`
type.

Every client request and direct reply requires `requestid`. A reply MUST repeat the request ID. Push updates, progress, and resync notices do not use request correlation. An optional `requestid` on a push event has no correlation meaning and MUST NOT be required by a receiver. A client MUST check reply type, request context, and resource identity before accepting a reply. A failure can reply to any request. Responses for different requests can arrive in any order.

## Session {#dasp-msg-003}

Requirement group **DASP-MSG-003**.

```text
SessionOpen = { session_id: ID, actor_id: ID, profile: Profile }
SessionOpened = { session_id: ID, actor_id: ID, profile: Profile, cursor: Cursor }
```

The client chooses the session ID. The profile tuple asserts the actor's one
immutable profile; it does not select a profile for that actor. Before first
open, the host MUST compare it with the actor's exact profile tuple. A mismatch
uses `unsupported_profile` and MUST NOT create or attach a session. On first
open, the host saves the identity, actor binding, and profile before replying.
On an authorized repeat, the same identity tuple reopens the session without
another creation. A changed actor or profile for an existing session
conflicts. The returned cursor is the current committed high-water mark, not
proof that this client applied those updates.

The host MUST also save the [extension protection requirements](extensions.md#dasp-ext-005) before the first successful reply. An equal tuple does not permit weaker protection on reopen. The host checks the saved requirements and current policy before confirming access or live delivery. The protection record adds no field to these closed core shapes.

A new session starts at cursor 0. Session creation itself does not consume an update sequence in this draft. Session expiry or deletion MUST NOT make the same ID available for an unrelated session.

A selected binding can make successful open also attach live delivery. The [first WebSocket delivery contract](websocket-live-delivery.md#dasp-ws-002) uses `session.opened` to confirm a new attachment before its pushes. An equal open that retains an active attachment preserves its recovery boundary and delivery position; its reply does not restart recovery. The session tuple and core shapes remain unchanged.

## Command and receipt {#dasp-msg-004}

Requirement group **DASP-MSG-004**.

```text
Command = {
  session_id: ID,
  command_id: ID,
  name: Name,
  input: Payload
}

Receipt = {
  session_id: ID,
  command_id: ID,
  disposition: "accepted" | "duplicate" | "rejected",
  admission_sequence: Sequence | null,
  error: Error | null
}
```

The profile defines `name` and `input`. The host MUST NOT infer chat, thread,
episode, or turn behavior. A profile-defined thread or episode stays in one
session and shares its history and cursor. A profile-defined `turn_id` needs
meaning that differs from `command_id`. Cancellation, steering, configuration,
or other controls can be profile commands with their own IDs and explicit
targets. The core does not promise support for them.

Accepted and duplicate receipts have the original admission sequence and a null error. Rejected receipts have a null admission sequence and a nonnull error. A duplicate reports the original saved admission, not current execution state.

## Saved updates {#dasp-msg-005}

Requirement group **DASP-MSG-005**.

```text
Update = {
  session_id: ID,
  sequence: Sequence,
  kind: "command.accepted" | "command.outcome" | "application",
  command_id: ID | null,
  payload: object
}
```

For `command.accepted`, `command_id` is required and nonnull; `payload` is exactly `{ "name": Name }`.

For `command.outcome`, `command_id` is required and nonnull; `payload` is the Outcome value below. An admitted command has at most one terminal outcome; a settled command has exactly one. Its sequence is greater than the command's admission sequence.

For `application`, `payload` is exactly `{ "name": Name, "data": Payload }`. The profile defines the name and data. The command ID can be null for an actor event not caused by a command. A nonnull ID MUST refer to an admitted command in this session.

## Outcomes {#dasp-msg-006}

Requirement group **DASP-MSG-006**.

```text
Outcome = {
  status: "completed" | "failed" | "cancelled" | "uncertain",
  output: Payload | null,
  error: Error | null
}

OutcomeRead = { session_id: ID, command_id: ID }

OutcomeReply = {
  session_id: ID,
  command_id: ID,
  state: "pending" | "settled",
  sequence: Sequence | null,
  outcome: Outcome | null
}
```

Completed outcomes have a nonnull output object and null error. Failed and uncertain outcomes have a nonnull error and MAY have partial output. Cancelled outcomes have a null error and MAY have partial output. Partial output never changes the status.

The profile MUST define what completion and cancellation establish. Completion does not imply that a user approved work or that external effects were rolled back. Uncertain means effects or required cleanup cannot be established.

A pending reply has null sequence and outcome. A settled reply contains the terminal update sequence and its exact saved outcome. Unknown or inaccessible command IDs return a protocol failure, never a false pending state.

## Views and replay pages {#dasp-msg-007}

Requirement group **DASP-MSG-007**.

```text
ViewRead = { session_id: ID }
View = {
  session_id: ID,
  actor_id: ID,
  profile: Profile,
  cursor: Cursor,
  state: Payload
}

UpdatesRead = { session_id: ID, after: Cursor, limit: integer 1..100 }
UpdatesPage = {
  session_id: ID,
  after: Cursor,
  next: Cursor,
  head: Cursor,
  events: [full dasp.v1.update CloudEvents]
}
```

A view contains a profile-defined state projection that includes all saved effects through its cursor and none after it. The host MUST read the projection and cursor coherently. Clients that need every fact still require replay; a view is not permission to skip audit records or forget unresolved command IDs.

An update page takes a stable high-water mark `head`. Its events start at `after + 1`, ascend contiguously, and do not exceed `head` or the requested limit. `next` is the last returned sequence, or `after` for an empty page. If `after < head`, the page MUST contain at least one event. To catch up without a fixed live-recovery boundary, clients continue while `next < head`; later reads can observe a newer head. With a confirmed live attachment and fixed boundary `H`, recover through `H`, then use buffered live delivery rather than chase newer page heads. `after > head` is a cursor error.

Nested events are the original saved CloudEvents. A new page has its own outer event ID and request ID. It MUST NOT replace nested event IDs with page-local identities.

## Progress and resync {#dasp-msg-008}

Requirement group **DASP-MSG-008**.

```text
Progress = {
  session_id: ID,
  command_id: ID | null,
  name: Name,
  payload: Payload
}

ResyncRequired = {
  session_id: ID,
  reason: "overflow" | "interrupted",
  head: Cursor
}
```

Progress has no saved sequence. It may be delayed, repeated, reordered, or lost. A nonnull command ID refers to an admitted command. Profiles define progress names and payloads. Neither progress nor a resync head advances the applied cursor.

On resync, the client MUST stop treating its live stream as complete and read saved events after its own last applied cursor. The host's head is informational.

The binding defines whether resync ends the attachment and how to restart it. In the [first WebSocket contract](websocket-live-delivery.md#dasp-ws-004), reopen before replay and discard late pages and failures for locally cancelled replay request IDs for that session. A pending open must finish or time out before another open is sent.

## Failure {#dasp-msg-009}

Requirement group **DASP-MSG-009**.

```text
Failure = { error: Error }
```

Core error codes are `invalid_message`, `unsupported_version`, `unsupported_profile`, `unsupported_command`, `not_found`, `conflict`, `invalid_cursor`, `limit_exceeded`, and `unavailable`. A profile MAY define additional codes in its own namespace.

Use a rejected receipt for a valid command whose admission is declined. Use failure for invalid requests, failed reads, or failures before a receipt can be established. If a malformed request has no valid request ID, the binding handles rejection without inventing correlation.

A protocol failure or timeout does not establish an execution outcome. `retryable` indicates that the same request may be attempted again; it never permits a new command ID for uncertain work.


## Operation rules {#dasp-msg-010}

Requirement group **DASP-MSG-010**.

The tables below apply after binding selection and authentication. A failure does not establish command settlement. Direct replies repeat the attempt's `requestid`.

| Request | Preconditions | Success reply | Saved effect | Repeat behavior |
| --- | --- | --- | --- | --- |
| `session.open` | Authorized actor, supported profile, valid identity | `session.opened` | Saves a new session tuple at cursor 0 | Same tuple reopens; changed tuple conflicts |
| `command` | Existing session, valid profile command, current permission | `receipt` | Accepted intent saves one admission fact | Equal admitted intent returns duplicate; changed intent conflicts |
| `view.read` | Current read permission | `view` | None | A new read can return a later coherent cursor |
| `updates.read` | Current read permission and cursor at or below head | `updates` | None | Saved nested events keep their identities; head can advance |
| `outcome.read` | Current read permission and admitted command | `outcome` | None | Pending can settle; settled value remains unchanged |

Push updates follow saved commits. Progress and resync notices add no saved fact. A binding defines whether live delivery exists and how it begins and recovers.

In the first WebSocket binding, an authorized successful open also starts live delivery; an equal open keeps its existing attachment. Connection close stops its streams. No subscription operation or additional core field is needed.

## Core error meanings {#dasp-msg-011}

Requirement group **DASP-MSG-011**.

| Code | Condition |
| --- | --- |
| `invalid_message` | Envelope or core data fails validation |
| `unsupported_version` | The required core contract cannot be selected |
| `unsupported_profile` | The requested profile version is not supported |
| `unsupported_command` | The selected profile does not support the command |
| `not_found` | Resource is absent or not accessible under the disclosure policy |
| `conflict` | An existing session tuple or admitted command identity has different semantic data |
| `invalid_cursor` | Requested cursor is greater than the committed head or invalid for the operation |
| `limit_exceeded` | Negotiated size, capacity, or sequence limits prevent the operation |
| `unavailable` | The host cannot currently serve the operation |

A valid command declined before admission uses a rejected receipt and its error code. A failed read or invalid request uses failure. Binding selection errors can occur before DASP framing; the binding specifies their representation. Profile validation errors use a documented profile code or `invalid_message` when no more specific code applies.

The `retryable` value describes whether another attempt may succeed under the current error condition. It is not a promise of eventual success and does not weaken command retry identity.
