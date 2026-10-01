# WebSocket live delivery

These rules define the delivery part of the selected first WebSocket binding. Successful `session.open` starts live delivery. `session.opened` confirms it and gives a fixed replay boundary. Closing the connection stops its session streams.

Normal live delivery requires no periodic history polling. Replay reads recover saved facts. Other bindings can use polling only. The core keeps five requests and fourteen message types. No core field, extension, message, or protocol version is added.

This delivery contract is part of the unreleased draft. The first binding uses a configured secure endpoint and one exact contract selection. Automatic discovery is outside this minimum binding. A complete binding still needs exact authenticated setup, framing before core selection, shared limit fields and values, health checks and deadlines, and a tested durability declaration under [DASP-PROFILE-002](profiles-and-bindings.md#dasp-profile-002). These rules alone do not establish released interoperability. [Issue #4](https://github.com/DASP-Protocol/dasp/issues/4) tracks this change.

## Selection and framing {#dasp-ws-001}

Requirement group **DASP-WS-001**.

The selected WebSocket binding MUST declare these live-delivery rules before session creation. A host that cannot supply required live delivery MUST fail selection. Authentication and selection MUST complete before core requests are accepted. Limits MUST be advertised under [DASP-ENV-004](cloudevents.md#dasp-env-004), including bounded host output queues and client recovery buffers.

The client MUST use a configured `wss://` endpoint and a trusted host-authority identity. The endpoint address MUST NOT replace authentication of that authority. The first binding does not require automatic discovery. Endpoint configuration and trusted identity administration are deployment concerns.

The client MUST request one exact core, profile, and binding contract with its required features and receive limits. The host MUST accept that contract or refuse setup; it MUST NOT select a different contract or remove a required feature. The host MUST propose concrete shared limits within the contract's bounds and both peers' declared requirements. The client MUST confirm the exact selected values or refuse setup. No core operation is permitted before both peers authenticate and confirm the selection. These requirements define selection behavior, not setup message bytes.

The complete binding MUST define each shared limit's field name, unit, allowed range, direction or scope, and exceeded-limit behavior. It MUST distinguish these shared values from local controls, such as connection-rate and parser-work limits. Each implementation MUST keep local work and memory bounded. Local controls need not be sent to the peer unless the binding makes them part of selection. Local control failures MUST follow the binding's refusal, resync, or close rules; they cannot silently discard required saved facts.

The resource boundaries below refer to existing rules. They do not select setup fields or new limit values.

| Resource | Limit source and scope | Behavior at the limit |
| --- | --- | --- |
| Core message and saved event | Shared receive bounds, no larger than [DASP-ENV-004](cloudevents.md#dasp-env-004). | Reject invalid input under the binding's error or close rules. Do not admit a command whose required facts cannot fit. |
| Replay page | Shared page bounds plus the request's limit; at most 100 events and the selected message byte limit. | Return a smaller contiguous page. A nonempty remaining interval requires at least one event under [DASP-MSG-007](messages.md#dasp-msg-007). |
| Host output and client recovery buffers | Declared finite bounds for the selected scope; local work and memory controls can be tighter. | Use [resync or close](#dasp-ws-004) when complete delivery cannot continue. Do not prune saved history. |
| Saved storage and admission capacity | Declared host capacity policy; not a client-selected retention period. | Refuse unsupported new work before admission. Preserve existing records under [DASP-CORE-012](recovery.md#dasp-core-012). |
| Encrypted carrier and authority evidence, when selected | Separate [carrier bounds](payload-encryption.md#dasp-enc-006) and [proof bounds](proof-of-authority.md#dasp-auth-004), in addition to core limits. | Apply the selected contract's rejection or close rule. No larger outer bound enlarges a core payload limit. |

One slow observer can require resync of its attachment or closure of its connection. This does not change another client's applied cursor or the saved history. Connection closure still ends every attachment on that connection under DASP-WS-005.

One WebSocket text message MUST carry one complete structured JSON CloudEvent. Requests and direct replies retain `requestid`; push events route through their existing `session_id`. Reply type, request context, and resource identity MUST be checked before a reply is accepted. If [encrypted delivery](payload-encryption.md) is selected, each logical event uses one carrier. Authenticate and decrypt that carrier before applying these correlation, routing, replay, and cursor rules. Its outer bounds apply to the WebSocket message; core bounds apply to the decrypted event. A transport acknowledgment is not evidence of admission, completion, or application of an update.

## Open, confirmation, and repeat {#dasp-ws-002}

Requirement group **DASP-WS-002**.

On an authorized successful open, the host MUST capture committed head `H` and attach delivery for every later saved sequence without a commit gap. It MUST release `session.opened` with `cursor: H` before updates or progress for the new attachment. If delivery setup fails, it MUST return a correlated `failure` and MUST NOT confirm delivery. Session creation still consumes no update sequence.

A new attachment MUST send saved pushes from `H + 1` in ascending sequence order until resync or connection close. Events through `H` remain available through replay. A new session has `H = 0`, so its first saved push is 1. The host MUST commit each event before release.

An equal open while delivery is active MUST retain the existing attachment, its delivery position, and queued saved events. It MUST NOT create another stream or move its start. The reply gives the committed head captured when the host handles that open. Commits can occur between head capture and reply receipt. Pushes from the retained attachment can arrive before or after this reply. The client MUST retain its existing recovery target, buffered events, and next expected push. It MUST NOT restart replay or treat this reply as a new recovery boundary. Its applied cursor can exceed the reply's head without a continuity failure.

A conflicting tuple MUST leave the original session and attachment unchanged. Open replies and resync notices for a session MUST follow the host's state-transition order on the wire. A resync after an open reply ends that attachment. A successful open reply after resync confirms a new attachment and supplies a new recovery boundary. If resync arrives while an open is pending, the client MUST wait for that request's reply or timeout before another open. A failure does not restart delivery; the client then opens the original tuple. This distinction uses the client's attachment state and wire order; it adds no core field.

The client MUST permit at most one pending open per session on a connection. Request IDs MUST be unique within that connection. An open timeout MUST cause connection close before another open attempt; the client then reopens the same tuple through fresh setup. This prevents a late reply from confirming the wrong attachment. Other sessions can have independent requests.

## Fixed-boundary replay {#dasp-ws-003}

Requirement group **DASP-WS-003**.

When an open reply confirms a new attachment, the client MUST retain its saved applied cursor `A` and buffer live saved updates while it replays history. That reply's `H` is a fixed recovery target, not an applied cursor. The client MUST recover every required saved event after `A` through `H`, then apply buffered events in sequence and continue with live delivery. An equal open that retains an attachment does not change this target.

When `A < H`, a bounded read can use `limit = min(selected_page_limit, H - A)`, where the selected page limit is at most 100. Each page keeps its own stable `head`, which can exceed `H`. The client MUST NOT issue further recovery reads only to chase that newer head. If a page contains events above `H`, apply them in sequence and compare overlapping buffered duplicates under the core rules. There is no need to discover later facts by periodic reads once complete live delivery is active.

For a new attachment, compare the saved applied cursor at confirmation with its captured `H`. When `A = H`, startup replay is unnecessary. When `A > H`, the client MUST stop recovery and treat continuity as failed. It MUST NOT reset its cursor to the lower head. This comparison does not apply to an equal-open reply for a retained attachment or to later progress beyond an existing target.

Each replay page and live push MUST preserve the original saved identity and semantic data. The client MUST apply only its next sequence and save its state with the applied cursor. Equal duplicates cannot be applied twice; changed duplicates are protocol violations. Missing comparison evidence requires a trusted coherent projection or a stop. A projection does not permit required audit records to be skipped. Unknown or invalid saved events stop cursor advancement.

Direct views, outcome reads, receipts, progress, transport acknowledgments, and resync heads do not skip earlier saved facts. Unresolved command retries retain their original command ID and semantic input. Ordinary explicit reads remain permitted while live delivery is active; they do not create or stop attachments.

## Overflow, resync, and restart {#dasp-ws-004}

Requirement group **DASP-WS-004**.

When complete delivery fails for a session, the host MUST stop its attachment and discard unsent update and progress output. It MUST send `resync.required` with reason `overflow` or `interrupted`. No later update or progress for the stopped attachment may follow that notice. If the notice cannot be sent, the host MUST close the connection. Direct request replies are separate from the stopped stream.

On resync, the client MUST keep its applied state and cursor, clear unapplied live buffers, and locally cancel pending replay requests for that session. It MUST discard later valid direct replies for those cancelled request IDs, including both pages and failures, before applying their application result. A push's optional `requestid` has no correlation meaning. It MUST reopen the original tuple to restart delivery and issue new replay reads after its current applied cursor. The one-pending-open rule still applies. Pending requests for other sessions remain valid. The resync head is informational and MUST NOT advance a cursor.

Client buffer overflow or a detected live sequence gap MUST cause connection close and recovery from the saved applied cursor. Host queues and client buffers MUST remain bounded during replay and ordinary live use. Overflow MUST NOT prune saved updates, outcomes, or retry records. Storage lifetime remains [DASP-CORE-012](recovery.md#dasp-core-012).

## Connection close and liveness {#dasp-ws-005}

Requirement group **DASP-WS-005**.

A client-requested close stops every attachment on that connection. The client MUST stop accepting live data when it starts the close. The host MUST stop delivery and discard unsent connection output when it receives the close. Already released output can arrive during closure; the close handshake confirms connection closure, not its application. Connection failure has the same attachment end. Neither close nor failure cancels admitted commands or deletes history.

The complete binding MUST define authenticated host health checks, deadlines, and close behavior at the binding layer. These checks MUST NOT require periodic history reads or add core commands. A peer that detects connection failure or expiration of its selected host-health deadline MUST close the connection. A client that reconnects MUST complete fresh authenticated setup and recover from its saved applied cursor. Health checks cannot establish application of a saved event or advance a cursor.

A later saved sequence reveals a gap. If a client silently discards the final event and no later event arrives, sequence checks alone cannot detect that loss immediately. Reconnect still recovers from the saved applied cursor. Do not claim immediate event-loss detection from health checks or infer an application acknowledgment protocol. Exact health-check messages and deadline values remain complete-binding work.

There is no separate stop operation for one session. A client that needs separate stop boundaries can use separate connections. Several sessions can still share a connection.

## Permission and session scope {#dasp-ws-006}

Requirement group **DASP-WS-006**.

An attachment belongs to `(connection, session_id)`. Different sessions can interleave; no global sequence order exists. Host resync for one session MUST leave the other attachments active unless the connection closes. Each client MUST retain its own applied cursor; a host delivery position or transport acknowledgment cannot replace it.

The host MUST check current permission on open, each read, and release of queued replies, updates, progress, and resync notices. Read permission revocation for an attached session MUST stop protected output and close the connection. Close reasons MUST disclose no protected session data or head. Do not send a resync head after its disclosure permission is revoked. Other sessions on that connection reconnect if still authorized. Saved retry decisions remain protected.

## Normal flow

After authentication and selection:

| Step | Message or action | Result |
| --- | --- | --- |
| 1 | `session.open` with the selected actor and profile | Create or reopen the session and attach delivery. |
| 2 | `session.opened` with `cursor: 0` | Confirm delivery; no initial replay is needed. |
| 3 | Profile command `counter.add` with a stable command ID | Save admission before acceptance. |
| 4 | Push saved updates 1, 2, and 3 | Apply admission, value change, and terminal outcome in sequence. |
| 5 | Continue with live pushes | No periodic history polling is needed. |
| 6 | WebSocket close | Stop every attachment on the connection. |

The receipt can arrive before or after saved pushes. It does not replace a saved update or prove completion.

## Reconnect and overlap

The client saved state at cursor 3. The host has committed through 6:

| Step | Message or action | Result |
| --- | --- | --- |
| 1 | Reopen the original tuple with a new request ID | Receive `session.opened.cursor: 6`; retain `A = 3`, fix `H = 6`. |
| 2 | Host commits and pushes event 7 during replay | Buffer 7. |
| 3 | Read with `{ "session_id": "session-counter", "after": 3, "limit": 3 }` | Receive original events 4, 5, 6; the page can report `head: 7`. |
| 4 | Apply and persist 4, 5, 6, then buffered 7 | Reach the fixed boundary, then continue live. No extra recovery read is needed to chase 7. |

The [recorded transcripts](../../conformance/fixtures/websocket-delivery-traces.json) contain complete core events for normal flow, reconnect overlap, and resync with a late cancelled-read reply. [Artifact checks](../../conformance/running-checks.md) verify these examples. They do not execute a WebSocket, host, or live client. Runtime fault cases remain [specified, not executed](../../conformance/behavioral-cases.md).
