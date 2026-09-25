# Model and lifecycle

## Actor and host {#dasp-model-001}

Requirement group **DASP-MODEL-001**.

An **actor** is a logical target that performs application work. Its identity does not identify a process, machine, language object, or connection.

A **host authority** owns sessions, command retry records, and saved updates. It can span multiple processes or machines. Its binding MUST publish a stable authority identity.

## Session identity {#dasp-model-002}

Requirement group **DASP-MODEL-002**.

A session binds one actor identity, one application profile version, and one ordered history. The tuple remains fixed for its lifetime. More than one authorized client MAY observe it. An actor MAY have more than one session. No ordering across sessions is defined.

Opening a new session saves its identity before replying. Reopening the same tuple does not create a new history. A changed actor or profile conflicts. A new session begins at cursor 0.

Draft-01 defines open and reopen. It does not define a wire operation for deletion, expiration, or migration. If host policy removes a session, its identity MUST NOT become available for unrelated work. The host MUST enforce the [retention and continuity rules](recovery.md#dasp-core-012).

## Command lifecycle {#dasp-model-003}

Requirement group **DASP-MODEL-003**.

A command is durable intent with a stable command ID. A receipt reports admission. An outcome records what the host can establish about execution.

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
