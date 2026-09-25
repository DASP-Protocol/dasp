# Seigyo Protocol: Session lifetime

These rules describe the existing coding v1 operations and the S07 corrections.
They do not add a wire field or change the frozen contract bundle. A Session
is durable context. A connection, execution process, and model request can
end while the Session and its saved Results remain.

## Configuration and admission

**SEIGYO-SESSION-001.** The server owns policy and executable capabilities.
The client can request only the closed configuration patch fields below.
Nested objects in a patch replace the complete field; they are not recursive
partial patches. Absent top-level fields retain their current values.

| Field | Rule |
| --- | --- |
| Session ID, protocol/profile contract, root/parent lineage, and Workspace ID | Fixed when the Session is created. A fork creates a new Session. A configuration patch cannot move an existing Session to another Workspace. |
| `tool_profile` | Server-defined executable tool identity with version and digest. It is returned in configuration and Results, but is not a client patch field. Unsupported saved tool identity fails new admission. |
| `model` | Model ID and reasoning level bind to each new `submit_turn` admission. Active and queued Commands keep their saved values. |
| `context` | Server-managed context mode, target token estimate, recent-turn count, and compaction policy. Binds at admission; compaction has a separate revision. |
| `instructions` | Bounded Session instructions included in subsequent request context. They do not replace the Agent's fixed system instructions. |
| `skills`, `plugins` | Bounded declared references used in request context. These lists do not install code, add runtime routes, or grant executable tools. The server tool profile remains the executable authority. |
| `execution` | Requested target, isolation, network, and Sandbox selection. A new patch is checked against server placement policy. Workspace identity stays fixed. Availability and execution leases are checked when work starts. |
| `revision`, `state`, `digest`, `version`, `profile` | Returned configuration evidence. The client cannot patch these values. The digest covers semantic configuration fields, excluding revision and pending/effective state. |

**SEIGYO-SESSION-002.** A new configuration mutation compares
`expected_revision` with the latest pending configuration, or the effective
configuration when no pending revision exists. One winner creates the next
revision and a saved `session_configured` Update. A stale writer receives
`conflict/config_revision`; it does not add an Update.

A repeated Mutation ID with equal validated request data returns its saved
configuration, sequence, previous revision, and effective boundary, with
`disposition: duplicate`. Later revisions do not replace this decision. Check
current authorization before returning it. Read a saved decision before
checking current execution placement; a stopped placement service must not
invalidate a committed configuration reply. Changed input under the same ID
returns `conflict/mutation_id`. A timeout does not prove rejection.

**SEIGYO-SESSION-003.** New Commands save their full configuration snapshot,
configuration revision and digest, context revision, and later resolved model
and execution evidence. Queued work binds configuration at admission, not
when it reaches the front of the queue. `turn_started` reports promotion; it
does not rebind configuration. A later configuration change cannot rewrite
an admitted Command or its Result.

`when_idle` applies immediately if there is no open work. Otherwise it stages
a pending revision. `next_command` stages a pending revision even when idle.
The next new admission consumes the pending revision, including admission to
the queue. An idle transition also promotes a `when_idle` revision when no
open Commands remain. Neither option changes already admitted work. The
configuration reply declares `current` or `next_command`; consumers must read
that decision instead of inferring a boundary from wall-clock time.

The two submission operations retain their [documented v1 model rules](messages.md).
`submit_turn` uses the saved Session configuration. Immediate `submit` permits
a per-Command model and uses runtime model selection when that field is
absent. The requested input remains part of retry identity; the resolved
model is separate saved execution evidence. `expected_config_revision` is a
new-admission precondition, not a reason to reject an equal admitted retry.

## Revisions and execution evidence

**SEIGYO-SESSION-004.** Keep these counters separate:

| Counter | Meaning |
| --- | --- |
| Session revision | Optimistic version of the Session record. |
| Update sequence / `event_cursor` | Order of saved public facts within one Session. |
| Configuration revision | Order of accepted configuration mutations. |
| Context revision | Order of committed model-context compactions. |
| Agent revision | Internal runtime evidence; never a substitute for a public replay cursor. |

Replacing an Agent or Plugin runtime cannot reset Session identity, lineage,
configuration history, retry decisions, or public Update order. Recovery
checks saved facts before it dispatches more work. It does not automatically
repeat an uncertain external effect. An open Session can have no available
execution process. `unavailable` describes a failed operation or unavailable
runtime; it does not mean that the Session or its saved Results were deleted.
The existing recovery and normalized-Result cases verify these distinctions.

**SEIGYO-SESSION-005.** `Result.model_id` is the saved model identity resolved
by the server for that execution. The configuration records the requested
model policy separately. Configuration revision, configuration digest, tool
profile identity, and context revision in a Result identify its saved input
boundary. A later model or runtime change does not alter those fields.

The current server does not implement automatic model fallback. An invalid
selection or unavailable dispatch fails explicitly. A future fallback must
save the effective selection and report it in the Result; it must not label
a different execution with the requested model ID. This field identifies the
server's selected provider/model route. It is not an attestation of a hidden
provider deployment revision.

**SEIGYO-SESSION-006.** Compaction is server-managed and occurs at a committed
idle boundary before new admission. It saves `context_compacted`, previous
and new context revisions, the configuration revision, source sequence
range, retained-turn count, token estimates, and reason. Estimates are not
byte limits or provider token measurements. Results use the context revision
saved for their Command. History and prior Results remain immutable; a
shortened model context does not remove conversation History. Public
provenance does not require disclosure of private reasoning text.

## Forks and side chats

**SEIGYO-SESSION-007.** Coding v1 accepts a fork only at the current committed
Session head, with no unfinished Command through that point. The final Store
transaction must recheck the requested head. A configuration or other Update
that commits while the fork is being prepared makes the fork fail with
`conflict/at_event_cursor`. A failed new fork does not expose a saved child.
Retry after reading a new coherent head.

The child records its parent, root, relation, fork cursor, Mutation ID, and
Workspace policy. It copies committed conversation entries through the cut,
the source context revision, and the source saved protocol requirements.
It cannot weaken the feature requirements needed to read inherited data.
It starts a new Session revision and Update sequence domain. Source Command
IDs in inherited conversation remain references to parent history; source
active work and external effects do not become child Commands.

`inherit` copies the effective configuration at the cut. Pending changes are
not inherited. `override` applies the closed patch to that effective
configuration. The child's execution configuration uses its selected
Workspace and Sandbox identity, with a new configuration digest as needed.
Future child and parent configuration changes are independent.

A `snapshot` Workspace policy creates a separate managed local copy when the
source is ready and has no active lease. It is a copy of available Workspace
bytes at fork preparation, not a historical filesystem at an arbitrary old
Update sequence. The final Session-head check prevents a protocol commit
from silently making that cut stale. External filesystem changes are outside
Session transaction ordering.

A `shared_read_only` or `shared_mutable` policy uses the same Workspace ID and
live bytes. A side chat defaults to shared read-only access. It is not a
private filesystem. Shared mutable work still uses Workspace reservation and
policy checks. Attachment IDs retain their original Session access scope;
fork lineage does not grant permission to reuse an Attachment in another
Session. A child must create its own valid Attachment for new input.

Equal fork retries return the original child even if the parent has advanced.
Changed fork input under that Mutation ID conflicts. Current authorization
still applies. Configuration and context copy rules do not permit copying
uncommitted execution state or restarting parent effects.
