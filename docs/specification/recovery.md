# Admission, durability, and recovery

These are DASP behavior requirements. CloudEvents envelopes alone do not provide them.

## Admission and retry

<a id="dasp-core-001"></a>

**DASP-CORE-001:** The host MUST authorize, validate the core shape, and validate the selected profile before admission.

<a id="dasp-core-002"></a>

**DASP-CORE-002:** Command IDs are unique across all sessions in one host authority. Retry equality compares the session ID, command name, and complete input. Object key order is ignored. Array order, exact Unicode strings, absent fields, explicit null, and empty values remain distinct. Profiles MUST NOT silently normalize retry data. Envelope metadata and request IDs do not enter this comparison.

<a id="dasp-core-003"></a>

**DASP-CORE-003:** Concurrent equal submissions MUST converge on one saved admission. A changed input, name, or session for an admitted ID MUST conflict. The host MUST check authorization before disclosing the saved decision. A rejected command with no saved admission does not reserve its ID.

<a id="dasp-core-004"></a>

**DASP-CORE-004:** Before acceptance is visible, the host MUST save the command identity, its retry data, and one `command.accepted` update as one recoverable decision. Separate stores are allowed only if recovery cannot expose a receipt without its fact or dispatch an unrecorded command. A duplicate returns the original sequence without another admission update or execution.

<a id="dasp-core-005"></a>

**DASP-CORE-005:** A timeout, failed connection, or lost reply MUST NOT cancel admitted work. Retry unresolved intent with the same command ID and data.

## Outcome authority

<a id="dasp-core-006"></a>

**DASP-CORE-006:** A command's saved terminal outcome is immutable. A stale worker cannot replace it or append a second terminal outcome. Reads MUST return the same saved value as the terminal update.

<a id="dasp-core-007"></a>

**DASP-CORE-007:** After owner loss, the host MUST reconcile saved admission and effect evidence before dispatch. If effects cannot be established, it MUST save `uncertain` and prevent unsafe repeat execution. Uncertainty is terminal in this core; reconciliation requires a separately specified profile and cannot rewrite the original fact.

<a id="dasp-core-008"></a>

**DASP-CORE-008:** Progress, transport acknowledgments, and receipts MUST NOT be used as completion evidence. A profile must define the required execution and cleanup boundary before it can emit completed or cancelled. Effects outside that boundary are not implied to have stopped.

The core guarantees no second admission for an equal retry. It does not guarantee exactly-once external effects. Hosts need application-level effect keys, transactional resources, or reconciliation to make stronger claims.

### Failure boundaries

This table applies DASP-CORE-003 through 009. Each row assumes current permission to recover the command. The host uses saved evidence, not the last message the client received.

| Failure boundary | Required recovery evidence | Permitted recovery action |
| --- | --- | --- |
| Before saved admission | An authoritative check establishes that no admission exists. | Validate and authorize a new admission. No earlier attempt may have dispatched unrecorded work. |
| After saved admission, before dispatch | Original command identity, complete retry data, and admission update; evidence that dispatch did not start. | Return the original admission for an equal retry. Start work from that admission only when safe. |
| After dispatch, before effects are established | Original admission and available ownership and effect evidence. | Reconcile before dispatch. Save `uncertain` if effects cannot be established; prevent unsafe repeat execution. |
| After external effects, before saved outcome | Original admission and evidence of the profile's execution and cleanup boundary. | Save the outcome that the evidence supports. An observed effect alone does not prove completion. Use `uncertain` when required effects or cleanup cannot be established. |
| After saved outcome, before reply | One immutable terminal outcome and its saved update, with their original identity and sequence. | Return the saved outcome and replay its original update. Do not execute again. |
| After a receipt or outcome reply | Original saved admission, outcome if settled, and history; the client's own saved checkpoint. | A lost reply or acknowledgment changes no saved command fact. Recover the command and client state from their respective records. |

An unavailable store is not evidence that an admission is absent. Missing dispatch evidence is not proof that dispatch did not occur. Store loss follows the [authority continuity rule](#dasp-core-012). When [proof of authority](proof-of-authority.md#dasp-auth-005) is selected, admission recovery also preserves its saved grant use and budget charge. Fresh connection keys do not create fresh command intent.

### What each signal proves

The [command lifecycle](model.md#dasp-model-003) has separate admission and settlement states.

| Signal or record | What it establishes | What it does not establish |
| --- | --- | --- |
| Transport acknowledgment | Only the transport boundary defined by the binding. | Saved admission, execution, settlement, or saved client state. |
| Accepted or duplicate receipt | One saved admission at the original admission sequence. | Current execution state or completion. |
| Rejected receipt | This attempt did not create an admission. A conflict can refer to an existing admitted ID. | Execution failure of previously admitted work. |
| Saved terminal outcome | What the host can establish within the profile's completion and cleanup scope. | Exactly-once effects outside that scope or application by any client. |
| Saved applied cursor | This client's saved state includes the required facts through that cursor. | Another client's position or permission to delete host history. |

Connection loss does not add a lifecycle transition. No application acknowledgment operation is required by these rules.

## Ordered facts

<a id="dasp-core-009"></a>

**DASP-CORE-009:** Updates start at sequence 1 and remain contiguous within a session. The host MUST commit an update before publishing it. Replays preserve the saved CloudEvents identity and semantic data. No global order across sessions is defined.

<a id="dasp-core-010"></a>

**DASP-CORE-010:** The client MUST apply sequence `cursor + 1` before advancing. It MUST save the applied cursor, application state, and retained duplicate-comparison evidence as one recoverable checkpoint. Delivery acknowledgment is not proof of application.

An identical update at an already applied sequence is a duplicate. A changed identity or data for the same session and sequence is a protocol violation. A client that no longer retains enough evidence to compare a duplicate MUST NOT apply it again or assume its contents match; it must recover a trusted saved projection or stop.

A gap requires replay. Malformed, unsupported, or unknown saved events stop cursor advancement. Clients MUST NOT skip them because a later event is readable.

For example, a client moves from cursor 8 to 9 by applying event 9. After a failed save, recovery uses the complete checkpoint at 8 or 9. Cursor 9 with state 8 would skip an unapplied fact. State 9 with cursor 8 could apply the fact again. Retained comparison evidence belongs to the same checkpoint; missing evidence still requires a trusted projection or a stop.

## Connection recovery {#dasp-core-011}

Requirement group **DASP-CORE-011**.

1. Reopen the authorized session with its original actor and profile. A live binding confirms its attachment and supplies a fixed recovery boundary before replay begins.
2. Read outcomes or retry unresolved commands with their original identity and data.
3. Read updates after the last applied cursor.
4. Validate session, identity, sequence, shape, and profile before applying each event.
5. For a live binding, recover through its fixed boundary and then apply buffered live events. Do not keep reading only to chase newer page heads. For a polling-only binding, continue reads under its paging policy.

The binding MUST define how replay and subscription overlap without losing committed events. A simple implementation can subscribe first, buffer live events, replay, and deduplicate by saved identity and sequence. Buffer overflow requires resync. A polling-only binding needs no live handoff.

The [first WebSocket delivery contract](websocket-live-delivery.md) attaches through open, restarts delivery through reopen after resync, and stops all streams through connection close. The host owns authoritative saved history. The client owns recovery of its applied state and cursor. Reconnect, replay, and command retries do not change saved identities, immutable outcomes, or the [storage lifetime](#dasp-core-012).

## Storage lifetime {#dasp-core-012}

Requirement group **DASP-CORE-012**.

Draft-01 retains all saved updates, outcomes, and retry records for the entire session lifetime. Pruning and snapshot-only recovery are not specified. Capacity exhaustion MUST reject new work rather than silently delete retry evidence.

A capacity refusal does not cancel admitted work or shorten its history. Storage failure alone is not a terminal outcome. The host can report a terminal outcome only after saving it under DASP-CORE-006 through 009.

A durable host MUST preserve these records across a host process restart. It MUST declare the tested durability boundary, including whether power loss and storage failures are covered. A volatile demo cannot advertise durable session conformance.

Deleted or expired identities MUST remain unavailable for reuse. A host that loses its store MUST NOT claim continuity under the same authority and session identity. Multi-client access does not change these rules: every client keeps its own applied cursor.
