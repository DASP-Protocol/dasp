# Profiles and transport bindings

## Application profile {#dasp-profile-001}

Requirement group **DASP-PROFILE-001**.

A profile supplies domain meaning while the core keeps the same shapes. Its immutable identity is an absolute URI plus a version string.

Every profile MUST publish:

- Supported command names and closed input schemas.
- Output schemas and completion scope for each command.
- Application update names, data schemas, and state projection rules.
- Progress names and payload schemas, if used.
- Error codes and any command preconditions.
- Execution concurrency, ordering, and cancellation behavior.
- Valid and invalid examples plus behavioral checks.

A session binds exactly one profile version. The host MUST reject an unsupported profile before session creation. A later profile version requires a new session or a future explicit migration protocol.

Application fields stay in `input`, outcome `output`, application-update `payload.data`, view `state`, and progress `payload`. A profile cannot redefine a receipt as completion, reset a cursor, or weaken retry identity.

A workflow profile could define `job.start`. A device profile could define `target.set`. An agent profile could define `task.run`. These are examples, not built-in core commands. Text, models, attachments, tools, and turns belong to profiles where needed.

The [counter example](example.md) defines a small illustrative profile. It is not a released standard profile.

## Transport binding {#dasp-profile-002}

Requirement group **DASP-PROFILE-002**.

The core specifies messages and behavior, not endpoints or connection frames. No specific HTTP, WebSocket, broker, or runtime binding is required by this draft.

Every binding MUST define:

1. Endpoint selection and secure connection setup.
2. Authentication and host-authority identity.
3. How the client discovers and selects the exact DASP draft or release, profile, supported commands, schema identifiers, and limits.
4. Structured CloudEvents framing and any transport acknowledgments.
5. Request routing, request-ID scope, reply routing, and timeout behavior.
6. Replay paging and, if supported, live subscriptions and race-free handoff.
7. Error handling before a request can be decoded.
8. Backpressure, reconnect behavior, and a durability declaration.

The selection MUST complete before application commands are admitted. Unsupported required features MUST fail selection. A host MUST NOT silently downgrade the selected profile or core version.

Binary CloudEvents encoding can be added by a future binding with a lossless mapping and shared vectors. Draft-01 examples use structured JSON only. An array of saved events inside an updates page is application data, not the CloudEvents batch event format.

A host can enforce admission limits without promising a queue. Queue policy and per-command ordering are profile behavior. The order of saved updates does not by itself mean commands executed serially.

## Multiple clients {#dasp-profile-003}

Requirement group **DASP-PROFILE-003**.

The core allows authorized clients to read the same session and submit profile commands. It does not define membership roles, presence, shared text editing, or conflict-free concurrent application edits.

Authorization policy remains a host concern. A collaboration profile or extension must define stronger multi-user behavior before clients rely on it. A client-provided user ID is never authority.

## Release boundary {#dasp-profile-004}

Requirement group **DASP-PROFILE-004**.

Draft-01 does not select the first production binding. A transport implementation and its conformance vectors are required before an independently built client can claim interoperability. This is an explicit remaining release decision.
