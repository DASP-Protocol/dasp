# Seigyo Protocol: Work

## Proposed work and schedule model

This section defines the target common model for asynchronous work,
subagents, and schedules. It is **Proposed**, not part of v1. It needs an ADR,
closed Signal schemas, Store rules, and conformance tests before any client
can depend on it. A Session is the shared context and event stream. A Work
record is one execution unit within that Session. A Command is a client
request and the retry authority. A Schedule is a durable rule that may create
Work later. A subagent may request child Work through a server capability. A
Session can contain several Work records over time and outlive them all.
Version 1 has no Work record or Work ID. Its `command_accepted` Update and
Receipt cannot be read as proof that Work has started.

| Identity | Meaning |
| --- | --- |
| `session_id` | Shared context, access boundary, and ordered event stream. |
| `command_id` | Client retry key for a submitted request. Its closed command kind states whether it creates Work. |
| `work_id` | Stable identity of one execution unit, regardless of who started it. |
| `parent_work_id` | Immediate parent for child Work; null for root Work. |
| `root_work_id` | Root of the Work tree; equals `work_id` for root Work. |
| `schedule_id` | Stable identity of a saved trigger definition. |
| `occurrence_id` | Stable identity of one scheduled firing and its retry key. |

Each Work record has a Session ID, kind, state, origin, author or system actor,
creation time, and optional parent. The Server assigns its Work ID. The
origin is `client`, `agent`, or `schedule`; it is distinct from the
authenticated User that configured or submitted it. Parent and root links
are immutable. A child stays in its parent's Session, and the Server rejects
a missing parent or a link that would form a cycle. An explicit child Session
needs a separate design; it would have its own access grants, cursor, and
lifecycle. A parent link cannot grant access to it. An Agent may start child
Work only through a server registered capability. It cannot forge a Client
Command or User identity. The Agent supplies a stable child request key
under its parent. A repeat with the same key returns the saved child link;
changed data conflicts. The Server saves that link before dispatch.

**Proposed admission mapping:** a closed Command kind states whether it can
create zero, one, or several Work units. Admission saves the Command intent.
Before the Server reports or dispatches a Work unit, it saves that unit and
its Command link. A duplicate Command returns the same saved intent and the
links present at read time. Recovery uses that intent and its stable key to
create each missing link once; a retry cannot start a second effect. A new
version may put
links saved at admission in its Receipt. A link added later appears in a
saved Update; it does not change the original Receipt. The closed v1 shapes
cannot gain `work_id`. The Command's accepted, completed, failed, and uncertain
meanings remain the client request outcome. Work state describes each
execution. Scheduled and Agent-created Work have no client Command ID. A
Schedule occurrence ID or Agent child request ID supplies their retry key.
An ADR must fix each creation transaction and the failure result before this
mapping becomes a contract.

Work states are `queued`, `running`, `waiting`, `completed`, `failed`,
`cancelled`, and `uncertain`. `waiting` has a closed, bounded reason. It has
a durable correlation value when it waits for an external target. `completed`,
`failed`, and `cancelled` are terminal. `uncertain` is blocked pending
evidence; reconciliation can settle it without repeating an unknown effect.
A retry of the origin key cannot create replacement Work while the saved Work
is uncertain. A terminal Work cannot return to `running` under the same
Work ID. A parent can finish only under the child completion policy saved
when that parent starts. Child failure does not silently change the parent's
state. An uncertain external effect blocks unsafe retry until reconciliation.
A cancelled parent does not prove that a child or external effect stopped;
cancellation needs a separate request identity, acknowledgement, and bounded
outcome. The Server does not report `cancelled` until it has evidence that the
Work can no longer
produce an effect. The Work state record and its saved Session Update must
agree at the same Store commit.

A Schedule records an authorized User or system actor, a target Session or
explicit new Session policy, a server approved Work template, and a closed
trigger. The trigger type supplies only the time and overlap fields it needs.
For example, a one-shot trigger can use one absolute UTC instant. Repeat and
calendar triggers need exact time zone, daylight-saving, missed-fire,
overlap, and edit semantics before release. The Server saves an occurrence
claim with a stable ID and the Schedule revision before it dispatches Work.
A restart or duplicate scheduler wakeup returns that claim and cannot create
a second Work record for the same occurrence. A skipped occurrence also has
a saved outcome, visible through a
bounded Schedule read or Session Update after reconnect, and creates no Work.
The exact result shape remains open. At fire time, Server checks the
actor's authority and target access. Loss of access skips the occurrence with
a saved reason. A Schedule is not an authority to bypass current grants. A
client disconnect has no effect on a saved Schedule or admitted Work. A later
ADR must define what happens when the Server was down at the one-shot instant,
and when a Schedule is edited or disabled while an occurrence is due.

Session listing is a first-class proposed read. The Server returns bounded,
authorized Session summaries in a declared stable order with an opaque page
cursor. The listing contract must state whether concurrent changes can cause
a repeat or omission during traversal. A client refreshes the list and reads
View plus Updates for authoritative Session state. Work and Schedule lists
have their own bounded reads and access checks. A Session View includes a
bounded set of active Work summaries; old Work is read by page. Subagent
activity must be readable after reconnect, not only during live delivery.
This list rule needs a new version and page type. Current local Store
listing uses ascending Session ID order; it has no remote authorized page
contract.

| ID | Behavioral requirement for the future common profile |
| --- | --- |
| SEIGYO-WORK-001 | When the Server admits a client Command under the Work profile, it shall save the intent and, before dispatch or report, each Work link allowed by that command kind. A duplicate shall return that intent and the links saved at read time without new execution; a rejected Command shall create no Work. |
| SEIGYO-WORK-002 | When a Client detaches, the Server shall continue accepted Work under the same Work ID and save its later state changes. |
| SEIGYO-WORK-003 | When an Agent starts child Work, the Server shall save the parent and root links before it reports the child to any Client. A repeat of its child request key shall return the same link, and changed data shall conflict. |
| SEIGYO-WORK-004 | When Work changes state, the Server shall append an ordered Session Update with the Work ID and closed state data. |
| SEIGYO-WORK-005 | When a Schedule becomes due, the Server shall admit at most one Work record for its occurrence ID under the stated failure model. |
| SEIGYO-WORK-006 | If the Schedule actor lacks authority or target access at fire time, then the Server shall skip the occurrence and save a safe reason that an authorized Client can read after reconnect, without starting Work. |
| SEIGYO-WORK-007 | When an authorized Client lists Sessions, the Server shall return a bounded page in a declared order, with an opaque cursor and documented behavior during concurrent changes. |
| SEIGYO-WORK-008 | If a Client reconnects after child or scheduled Work changes, then the Server shall let it recover those changes through saved Updates and bounded reads. |
| SEIGYO-WORK-009 | If Work has an uncertain external effect, then the Server shall not repeat that effect from a client retry or scheduler retry. |

The exact mutation and result Signals still need design. The catalog must
add closed types for Work status and pages, Schedule operations and listing,
plus saved Work and Schedule Update variants. Each public message needs one
versioned schema and conformance fixtures. Do not expose a generic executable
payload or module name to a client. The v1 `Command` shape remains unchanged
until a new version is defined. No v1 Session list type is assigned.
