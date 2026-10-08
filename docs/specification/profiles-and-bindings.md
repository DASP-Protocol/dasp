# Profiles and transport bindings

## Application profile {#dasp-profile-001}

Requirement group **DASP-PROFILE-001**.

A profile supplies domain meaning while the core keeps the same shapes. Its immutable identity is an absolute URI plus a version string.

Every profile MUST publish:

- Its complete command capability universe. It MUST mark each capability as
  required or optional.
- Supported command names and complete input schema contracts.
- Output schemas and completion scope for each command.
- Application update names, data schemas, and state projection rules.
- Progress names and payload schemas, if used.
- Error codes and any command preconditions.
- Execution concurrency, ordering, and cancellation behavior.
- Valid and invalid examples plus behavioral checks.

### Progressive capability discovery

The optional [capability-discovery
contract](capability-discovery.md#dasp-disc-001) reveals one actor's exact
profile and advertised command view before normal profile confirmation. It
uses bounded summaries, selective details, and exact resource reads. It does
not use one all-at-once catalog document.

Each actor has one exact profile URI and version for its lifetime. Its
effective capability set contains all required profile capabilities and can
contain activated optional capabilities. It MUST NOT contain a capability
outside the profile universe. An advertised view can filter that effective
set. It cannot add or activate a capability.

A session binds exactly the actor's profile version. The profile tuple in
`session.open` is an assertion, not a choice. The host MUST reject a mismatch
before session creation or attachment. An incompatible profile change requires
a new actor identity unless a future explicit migration protocol defines
another safe transition.

Application fields stay in `input`, outcome `output`, application-update `payload.data`, view `state`, and progress `payload`. A profile can put a thread, episode, turn, or parent-child link in this application data. A thread or episode stays in one session and uses that session's history and cursor. A turn ID is needed only when it differs in meaning from the command ID. A parent-child link transfers no authority or discovery state. A profile cannot redefine a receipt as completion, reset a cursor, or weaken retry identity.

A workflow profile could define `job.start`. A device profile could define `target.set`. An agent profile could define `task.run`. These are examples, not built-in core commands. Text, models, attachments, tools, and turns belong to profiles where needed.

The [counter example](example.md) defines a small illustrative profile. It is not a released standard profile.

## Transport binding {#dasp-profile-002}

Requirement group **DASP-PROFILE-002**.

The core specifies messages and behavior, not endpoints or connection frames. No specific HTTP, WebSocket, broker, or runtime binding is required by this draft.

Every binding MUST define:

1. Endpoint selection and secure connection setup.
2. Authentication and host-authority identity.
3. How the client obtains and selects the exact DASP draft or release, profile, supported commands, schema identifiers, and limits. Configuration can supply this information. A binding can also define an exact mapping for the optional capability-discovery setup contract.
4. Structured CloudEvents framing and any transport acknowledgments.
5. Request routing, request-ID scope, reply routing, and timeout behavior.
6. Replay paging and, if supported, live subscriptions and race-free handoff. A live binding defines start, confirmation, first sequence, repeated setup, stop scope, resync state, and a finite replay boundary.
7. Error handling before a request can be decoded.
8. Backpressure, reconnect behavior, and a durability declaration.
9. Exact extension identities, versions, content pins, settings, scopes, dependencies, authenticated mutual confirmation, and saved session protection under [DASP-EXT-001 through 008](extensions.md).

When discovery is selected, its exact mapping selection and authentication MUST
complete before the first discovery operation. After discovery, normal
selection MUST confirm the exact actor profile before `session.open` or any
other core operation. Unsupported required features MUST fail selection. A
host MUST NOT silently downgrade the selected profile, core version,
extension, or protection requirement. Reconnect requires fresh confirmation
and enforcement of each session's saved protection floor before protected
access.

Binary CloudEvents encoding can be added by a future binding with a lossless mapping and shared vectors. Draft-01 examples use structured JSON only. An array of saved events inside an updates page is application data, not the CloudEvents batch event format.

A host can enforce admission limits without promising a queue. Queue policy and per-command ordering are profile behavior. The order of saved updates does not by itself mean commands executed serially.

## Multiple clients {#dasp-profile-003}

Requirement group **DASP-PROFILE-003**.

The core allows authorized clients to read the same session and submit profile commands. It does not define membership roles, presence, shared text editing, or conflict-free concurrent application edits.

Authorization policy remains a host concern. A collaboration profile or extension must define stronger multi-user behavior before clients rely on it. A client-provided user ID is never authority.

## Release boundary {#dasp-profile-004}

Requirement group **DASP-PROFILE-004**.

Draft-01 does not select the first production binding. A transport implementation and its conformance vectors are required before an independently built client can claim interoperability. This is an explicit remaining release decision.

The selected first WebSocket binding requires the [live-delivery contract](websocket-live-delivery.md). It uses a configured `wss://` endpoint and trusted host-authority identity. The client requests one exact contract; both peers must confirm shared settings before core operations. Its successful open starts observation; connection close stops all session streams. Normal operation uses live updates, with saved replay for startup and recovery. This minimum binding does not include a capability-discovery mapping. A later exact mapping can add the optional setup subprotocol without changing core types. Exact authenticated setup, shared limit fields and values, health checks and deadlines, and tested production behavior remain incomplete. Separate polling-only bindings remain valid.

The [encrypted-delivery contract](payload-encryption.md) uses a binding carrier around the original core CloudEvent. Its outer shape has a separate schema and limits; the decrypted message retains the core's shapes and limits. Its accepted design scope permits the executing host to read payloads, requires recovery history or attachment refusal, and states the static reader-key compromise limit. Configured trusted keys and the setup flow are defined as design requirements. Exact setup bytes and security evidence remain incomplete; this is not a complete interoperable binding.

The optional [proof-of-authority contract](proof-of-authority.md) carries signed grants in a required selected extension outside profile input. Standing grants permit repeated new admissions within explicit scope and time limits; an admission-count budget is optional. Existing authorized retries preserve semantic equality and charge no new grant use. Required authority selection must be authenticated with the binding settings. Host policy prevents selection of a weaker contract from bypassing required proof.
