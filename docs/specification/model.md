# Sessions and command lifecycle

## Actor and host {#dasp-model-001}

Requirement group **DASP-MODEL-001**.

An **actor** is a logical target that performs application work. Its identity does not identify a process, machine, language object, or connection.

One actor has one exact profile URI and version for its lifetime. An
incompatible profile change requires a new actor identity unless a future
explicit migration contract defines another safe transition. A sub-actor is
either an opaque profile implementation detail or a separate actor with its
own discovery and session lifecycle. See the [capability-discovery actor
boundary](capability-discovery.md#dasp-disc-014).

A **host authority** owns sessions, command retry records, and saved updates. It can span multiple processes or machines. Its binding MUST publish a stable authority identity.

## Session identity {#dasp-model-002}

Requirement group **DASP-MODEL-002**.

A session binds one actor identity, that actor's exact application profile
version, and one ordered history. The tuple remains fixed for its lifetime.
The profile in `session.open` is an assertion, not a profile choice. The host
MUST reject a tuple that does not match the actor's immutable profile before it
creates or attaches the session. More than one authorized client MAY observe
it. An actor MAY have more than one session. Each session has its own history
and cursor. No ordering across sessions is defined.

Opening a new session saves its identity before replying. Reopening the same tuple does not create a new history. A changed actor or profile conflicts. A new session begins at cursor 0.

Draft-01 defines open and reopen. It does not define a wire operation for deletion, expiration, or migration. If host policy removes a session, its identity MUST NOT become available for unrelated work. The host MUST enforce the [retention and continuity rules](recovery.md#dasp-core-012).

## Command lifecycle {#dasp-model-003}

Requirement group **DASP-MODEL-003**.

A command is durable intent with a stable command ID. A receipt reports admission. An outcome records what the host can establish about execution.

A profile can group commands as one thread or episode in application data.
Each command still has its own command ID. The group shares the session history
and cursor. It has no independent core admission, replay, recovery, or cursor.
The core command is the unit closest to a turn. A profile needs `turn_id` only
when that identifier has meaning that differs from `command_id`.

| State | Permitted evidence |
| --- | --- |
| Not admitted | No admission update; a rejection can be returned |
| Admitted and pending | One saved admission; no terminal outcome yet |
| Settled | One immutable completed, failed, cancelled, or uncertain outcome |

A receipt of `duplicate` reports an existing admission, not a new lifecycle state. Pending does not assert that a worker is currently running. A transport failure does not transition admitted work to cancelled.

Once settled, a command MUST NOT return to pending or acquire a different terminal outcome. The host MUST follow the [admission and recovery rules](recovery.md) when a worker or owner is lost.

## Saved and temporary data {#dasp-model-004}

Requirement group **DASP-MODEL-004**.

An update is an immutable saved session event. A view is a coherent projection at a saved cursor. Progress is temporary information that clients MAY discard.

Only applied saved updates or an explicitly recovered coherent projection establish a client's saved state. Progress, request IDs, timestamps, and transport acknowledgments MUST NOT advance its applied update cursor. A view does not authorize skipping required audit history.

The host orders saved facts within a session. A profile defines command execution order and application conflicts. The saved sequence alone does not require serial execution.
