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

## Ordered facts

<a id="dasp-core-009"></a>

**DASP-CORE-009:** Updates start at sequence 1 and remain contiguous within a session. The host MUST commit an update before publishing it. Replays preserve the saved CloudEvents identity and semantic data. No global order across sessions is defined.

<a id="dasp-core-010"></a>

**DASP-CORE-010:** The client MUST apply sequence `cursor + 1` before advancing. It MUST save the applied cursor with its application state. Delivery acknowledgment is not proof of application.

An identical update at an already applied sequence is a duplicate. A changed identity or data for the same session and sequence is a protocol violation. A client that no longer retains enough evidence to compare a duplicate MUST NOT apply it again or assume its contents match; it must recover a trusted saved projection or stop.

A gap requires replay. Malformed, unsupported, or unknown saved events stop cursor advancement. Clients MUST NOT skip them because a later event is readable.

## Connection recovery {#dasp-core-011}

Requirement group **DASP-CORE-011**.

1. Reopen the authorized session with its original actor and profile.
2. Read outcomes or retry unresolved commands with their original identity and data.
3. Read updates after the last applied cursor.
4. Validate session, identity, sequence, shape, and profile before applying each event.
5. Continue until caught up, then use the binding's race-free live handoff.

The binding MUST define how replay and subscription overlap without losing committed events. A simple implementation can subscribe first, buffer live events, replay, and deduplicate by saved identity and sequence. Buffer overflow requires resync. A polling-only binding needs no live handoff.

## Storage lifetime {#dasp-core-012}

Requirement group **DASP-CORE-012**.

Draft-01 retains all saved updates, outcomes, and retry records for the entire session lifetime. Pruning and snapshot-only recovery are not specified. Capacity exhaustion MUST reject new work rather than silently delete retry evidence.

A durable host MUST preserve these records across a host process restart. It MUST declare the tested durability boundary, including whether power loss and storage failures are covered. A volatile demo cannot advertise durable session conformance.

Deleted or expired identities MUST remain unavailable for reuse. A host that loses its store MUST NOT claim continuity under the same authority and session identity. Multi-client access does not change these rules: every client keeps its own applied cursor.
