# Seigyo Protocol messages and submission

## Message roles

| ID | Requirement |
| --- | --- |
| SEIGYO-MESSAGE-001 | A Request invokes an advertised operation or delivery control. A Reply answers one request reference. An Event reports saved data, transient data, or delivery state. The Signal envelope is not a fourth role. A decoder MUST reject a type whose role is not legal in that direction and route. |
| SEIGYO-MESSAGE-002 | A correlatable Request MUST have one logical Reply, either success or failure. A submission success carries a Receipt; it does not establish completion. A lost connection can prevent delivery. A Reply MUST match both the Phoenix reference and the Seigyo request reference. Unknown, duplicate, or late Replies MUST NOT complete another call or change saved state. |
| SEIGYO-MESSAGE-003 | A client MUST use unique request references while its calls are pending. The server MUST NOT reinterpret a duplicate transport delivery as an execution retry key. Reference reuse after the server issues a Reply is permitted; only Command and Mutation IDs provide durable retry semantics. The v1 channel processes calls serially, so it has no concurrent handler intervals on one connection. Other implementations MUST reject overlapping reference use before dispatch. |
| SEIGYO-MESSAGE-004 | A malformed Request with a valid reference MUST receive a correlated failure. If no valid, bounded request reference can be read, the failure MUST use null. A supplied invalid reference MUST NOT be copied into a Reply. Unsupported Phoenix events have no Seigyo correlation and return `invalid_field/event` with a null reference. |
| SEIGYO-MESSAGE-005 | Operation, Signal type, role, version, source, and route MUST agree before effects. The current namespace is `jido.client.v1.*`; the version precedes the message name. It is owned by Seigyo and is not a generic Jido route. Events have no request reference and require no Reply. Local `ack_update/2` is not a server acknowledgement. |

The Request grammar remains the closed v1 `call` payload with `op`,
`request_ref`, and exactly one of `signal` or `args`, selected by the catalog.
Reply grammar remains the Phoenix `phx_reply` status and a closed `response`
with `request_ref` plus exactly one of `result` or `failure`. The control reply
for `watch_progress` uses `session_id`. Events use `update`, `progress`, or
`resync_required` and one server Signal. The catalog defines every mapping.

The client ignores a Reply whose Phoenix reference is no longer pending. This
includes an unsolicited Reply and a late Reply after timeout. For a pending
reference, a wrong Seigyo reference, wrong type, or invalid closed shape fails
that call with a client protocol error. It cannot satisfy another call. A
duplicate success cannot complete a call twice. A server Event sent on a
Request route fails before admission, even if its source is forged.

## Current submission map

Both operations create the same public Command identity and saved Update and
Result lifecycle. Neither creates a public Jido Agent Turn or a Work graph.

| Behavior | `submit` | `submit_turn` |
| --- | --- | --- |
| Input Signal | `jido.client.v1.command`; `id`, `kind: submit_text`, and nested `input` | `jido.client.v1.turn.submit`; `command_id`, text, Attachment IDs, delivery, and expected configuration revision |
| Busy behavior | Immediate admission only; Workspace or active work conflict produces a rejected Receipt | `enqueue` can admit queued work; `reject_if_busy` returns rejected Receipt with `conflict/delivery` |
| Queue order | No new queued admission | Saved admission sequence determines promotion order |
| Attachments | Optional ordered `input.attachment_ids`; absent means an empty list at use | Required ordered `attachment_ids`; helper supplies an empty list |
| Model | Optional per-Command `input.model`; absent uses runtime model selection | Uses the Session configuration; no per-Command model field |
| Revision check | No wire expected-configuration revision field | Nullable `expected_config_revision`; a supplied value checks new admission |
| Context | Existing immediate path | Managed context compaction can occur before new admission |
| Reply | Receipt with disposition, saved revision, sequence, and error | TurnReceipt adds `active` or `queued`; rejected state is null |
| Retry | Command ID, Session, kind, and semantic input | Same saved Command comparison after conversion; delivery and revision preconditions are not part of an already admitted Command's input |
| Default helper | `submit_text` uses immediate admission | `submit_turn` supplies `delivery: reject_if_busy` and a null revision precondition; callers select `enqueue` explicitly |
| Completion | Read the saved Result named by a terminal Update | Same |

An absent optional input field and an explicit empty collection are not
automatically equal in the current saved request comparison. S04 specifies
those cases. Cross-operation retries must use the same stored input, including
Attachment field presence. A changed model or text conflicts. Retry never
creates a second execution of an admitted Command.

## Compatibility decision for S03

Keep both v1 operations and the current namespace. They have different
admission and model semantics, so treating them as aliases would break v1.
No operation rename or merged wire grammar is approved. This is the existing
preserve-v1 decision from S01, not approval of a new API.

For a later approved contract, use one submission operation with explicit
delivery policy, typed content, configuration preconditions, and model policy.
`submit_turn` is the starting behavior because it already expresses queue
policy. Keep a text helper that builds that one operation. A new contract must
account for the `submit` model override before it can replace both paths.
The term Command remains the durable work identity; Turn remains a conversation
grouping. Dot-qualified names are recommendations for that future contract.
