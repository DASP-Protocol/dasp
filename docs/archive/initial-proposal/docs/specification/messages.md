> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Message reference

All methods below belong to draft `0.1.0-draft.1`. Parameters are JSON objects. All fields are required unless marked optional. All methods are client requests except `session.changed`.

## initialize

Parameters: `protocolVersions` (non-empty array of version strings in preference order).

Result: `protocolVersion` (selected string), `limits` (object with positive integer `maxMessageBytes` and `maxPendingRequests`). Byte limits apply to the complete UTF-8 JSON message in both directions. Pending request limits apply per connection. Hosts SHOULD document pre-initialization limits at the endpoint.

The host MUST select the first offered version that it supports. It MUST reject a second initialization on the same connection. No shared version produces `UNSUPPORTED_VERSION`, with `supportedVersions` in error data. No other requests are permitted after this error; the host closes the connection after the response.

## session.open

Parameters: `sessionId` (string), `actorId` (string).

Result: `snapshot` (snapshot object).

The host MUST atomically create the session and its initial state before success. If the authorized principal opens the same session for the same actor again, the host returns its current snapshot, including closed status. A different actor produces `SESSION_CONFLICT`. Application-specific actor provisioning occurs outside DASP; an unavailable actor produces `NOT_FOUND`.

Opening a session does not subscribe to updates. The host MUST check authorization even when the session already exists.

## session.read

Parameters: `sessionId` (string).

Result: `snapshot` (snapshot object).

The result MUST represent a committed state at one point during the request. Reads MUST NOT return uncommitted state. Concurrent commands can commit after that point.

## session.command

Parameters:

| Field | Type | Meaning |
| --- | --- | --- |
| `sessionId` | string | Target session |
| `commandId` | string | Non-empty retry identity, unique within the session |
| `name` | string | Application command name |
| `input` | JSON value | Application command input |
| `expectedRevision` | decimal string, optional | Required session revision before execution |

Result: `commandId` (string), `revision` (decimal string), `output` (JSON value).

A success response means the outcome and resulting state are durably committed. It does not mean that an external service has completed work. External work is covered in the [recovery rules](recovery.md).

The host first checks for a stored command record. A matching retry returns the stored outcome. Reuse with different command content produces `COMMAND_CONFLICT`. For a new command, the host checks session status and `expectedRevision` before application execution. A mismatch produces `REVISION_CONFLICT` with `currentRevision` in error data.

The application contract defines command names, input, output, and state. An application rejection produces `COMMAND_REJECTED`. A successful command MAY leave state unchanged; its result then carries the current revision. If a command changes several session views for the same actor, all affected state and command records MUST commit atomically. Each changed session gets its own next revision and notification.

## session.result

Parameters: `sessionId` (string), `commandId` (string).

Result is one of:

- `{ "status": "unknown" }`: no committed outcome is available. Work might still be running.
- `{ "status": "succeeded", "result": ... }`: the stored `session.command` result.
- `{ "status": "rejected", "error": ... }`: the stored error object for that command.

An unknown outcome is not proof that a command failed. A retry MUST use the original command identifier and content. If the session does not exist or is not accessible, return the corresponding request error instead of `unknown`.

## session.subscribe

Parameters: `sessionId` (string).

Result: `subscriptionId` (non-empty string unique on the connection), `snapshot` (snapshot object).

The host MUST atomically select a snapshot revision and register the subscription. It MUST send the response before notifications for that subscription. Later notifications contain every subsequent committed revision in order. There MUST be no gap between the returned snapshot and live updates.

The first draft uses a new snapshot on every subscription, including after reconnect. It does not provide an event replay API. A new subscribe request creates a separate subscription.

## session.changed

Host notification parameters: `subscriptionId` (string), `snapshot` (snapshot object).

The snapshot contains the complete view at that revision. The host MUST NOT combine several revisions into one update. The client MUST replace the local view with the snapshot; no language-specific reducer is required.

Notifications and command responses can arrive in either order after a commit. A command response does not replace subscription state. Clients MUST NOT apply a state change twice because both messages arrived.

## session.unsubscribe

Parameters: `subscriptionId` (string).

Result: `{}`.

The host stops the subscription before it sends success. Earlier notifications can arrive before that response. No notification for that subscription can follow the response. Repeated unsubscribe for an absent subscription succeeds.

## session.close

Parameters: `sessionId` (string).

Result: `snapshot` (snapshot object).

The host serializes close with commands for the actor. It durably changes the session status to `closed` and increments the revision once. Subscriptions receive that change and remain available for observation. A repeated close returns the current closed snapshot without another revision. Earlier commands finish before close; later new commands produce `SESSION_CLOSED`. Stored command retries still return their original outcome.

## Errors

JSON-RPC errors use `code` (integer), `message` (string), and optional `data` (object). DASP errors below MUST include `data.kind`. Clients branch on `kind`, not on message text.

| Code | Kind | Meaning |
| --- | --- | --- |
| -32001 | `NOT_INITIALIZED` | Initialization is required |
| -32002 | `UNSUPPORTED_VERSION` | No shared version |
| -32003 | `NOT_FOUND` | Resource is absent or not disclosed |
| -32004 | `FORBIDDEN` | Principal lacks permission |
| -32005 | `SESSION_CONFLICT` | Session already belongs to another actor |
| -32006 | `SESSION_CLOSED` | Session rejects new commands |
| -32007 | `COMMAND_CONFLICT` | Retry identifier has different content |
| -32008 | `REVISION_CONFLICT` | Session revision does not match |
| -32009 | `COMMAND_REJECTED` | Application rejected the command |
| -32010 | `BUSY` | Host cannot accept the request now |
| -32011 | `LIMIT_EXCEEDED` | A declared limit was exceeded |

Standard JSON-RPC errors retain their meanings: parse error `-32700`, invalid request `-32600`, unknown method `-32601`, invalid parameters `-32602`, internal error `-32603`. A second initialization uses invalid request. Parse errors and invalid requests without a valid identifier use `id: null` in the response.

A transport failure, timeout, or internal error can leave a command outcome unknown. Clients MUST preserve the command identifier for recovery. `BUSY` and `LIMIT_EXCEEDED` do not authorize a new identifier for the same intended operation.
