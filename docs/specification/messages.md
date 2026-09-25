# Generic message shapes

All messages use the [CloudEvents envelope](cloudevents.md). The names below are **draft DASP names**. They do not identify an existing released service.

Fields in each shape are required unless marked `?`. Optional and null are different. Core objects are closed, including the `error` and `profile` objects.

## Shared values

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

## Catalog

Each type starts with `dasp.` and ends with `.v1`. Version 1 is a draft namespace until release.

| Type | Direction | Meaning |
| --- | --- | --- |
| `dasp.session.open.v1` | Client → host | Create or reopen a session |
| `dasp.session.opened.v1` | Host → client | Saved session identity |
| `dasp.command.v1` | Client → host | Issue application intent |
| `dasp.receipt.v1` | Host → client | Admission decision |
| `dasp.update.v1` | Host → client | Immutable saved fact |
| `dasp.progress.v1` | Host → client | Temporary activity |
| `dasp.view.read.v1` | Client → host | Read a coherent projection |
| `dasp.view.v1` | Host → client | Projection at a cursor |
| `dasp.updates.read.v1` | Client → host | Read saved events after a cursor |
| `dasp.updates.v1` | Host → client | Bounded page of saved events |
| `dasp.outcome.read.v1` | Client → host | Read command settlement |
| `dasp.outcome.v1` | Host → client | Known outcome or pending state |
| `dasp.resync.required.v1` | Host → client | Live delivery no longer complete |
| `dasp.failure.v1` | Host → client | Request failed at the protocol boundary |

Every client request and direct reply requires `requestid`. A reply MUST repeat the request ID. Push updates, progress, and resync notices do not use request correlation. A client MUST check reply type, request context, and resource identity before accepting a reply. A failure can reply to any request. Responses for different requests can arrive in any order.

## Session

```text
SessionOpen = { session_id: ID, actor_id: ID, profile: Profile }
SessionOpened = { session_id: ID, actor_id: ID, profile: Profile, cursor: Cursor }
```

The client chooses the session ID. On first open, the host saves the identity, actor binding, and profile before replying. On an authorized repeat, the same identity tuple reopens the session without another creation. A changed actor or profile conflicts. The returned cursor is the current committed high-water mark, not proof that this client applied those updates.

A new session starts at cursor 0. Session creation itself does not consume an update sequence in this draft. Session expiry or deletion MUST NOT make the same ID available for an unrelated session.

## Command and receipt

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

The profile defines `name` and `input`. The host MUST NOT infer chat or turn behavior. Cancellation, steering, configuration, or other controls can be profile commands with their own IDs and explicit targets. The core does not promise support for them.

Accepted and duplicate receipts have the original admission sequence and a null error. Rejected receipts have a null admission sequence and a nonnull error. A duplicate reports the original saved admission, not current execution state.

## Saved updates

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

For `command.outcome`, `command_id` is required and nonnull; `payload` is the Outcome value below. There is exactly one terminal outcome per admitted command. Its sequence is greater than the command's admission sequence.

For `application`, `payload` is exactly `{ "name": Name, "data": Payload }`. The profile defines the name and data. The command ID can be null for an actor event not caused by a command. A nonnull ID MUST refer to an admitted command in this session.

## Outcomes

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

## Views and replay pages

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
  events: [full dasp.update.v1 CloudEvents]
}
```

A view contains a profile-defined state projection that includes all saved effects through its cursor and none after it. The host MUST read the projection and cursor coherently. Clients that need every fact still require replay; a view is not permission to skip audit records or forget unresolved command IDs.

An update page takes a stable high-water mark `head`. Its events start at `after + 1`, ascend contiguously, and do not exceed `head` or the requested limit. `next` is the last returned sequence, or `after` for an empty page. If `after < head`, the page MUST contain at least one event. Clients continue while `next < head`; later reads can observe a newer head. `after > head` is a cursor error.

Nested events are the original saved CloudEvents. A new page has its own outer event ID and request ID. It MUST NOT replace nested event IDs with page-local identities.

## Progress and resync

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

## Failure

```text
Failure = { error: Error }
```

Core error codes are `invalid_message`, `unsupported_version`, `unsupported_profile`, `unsupported_command`, `not_found`, `conflict`, `invalid_cursor`, `limit_exceeded`, and `unavailable`. A profile MAY define additional codes in its own namespace.

Use a rejected receipt for a valid command whose admission is declined. Use failure for invalid requests, failed reads, or failures before a receipt can be established. If a malformed request has no valid request ID, the binding handles rejection without inventing correlation.

A protocol failure or timeout does not establish an execution outcome. `retryable` indicates that the same request may be attempted again; it never permits a new command ID for uncertain work.
