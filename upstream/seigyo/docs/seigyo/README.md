# Seigyo Protocol

Status: Coding v1 has a generated local WebSocket release bundle and black-box verifier

Date: 2026-09-18

This document set is the one specification for the Seigyo Protocol client boundary.
Seigyo (制御) means technical or system control. Jido Code is the current
server implementation, and WebSocket is the current transport. Neither is
part of the protocol name. [ADR 0021](../adr/0021-seigyo-protocol-name.md)
records this naming decision.

The specification defines operations, Signal data, delivery, recovery, and
test rules. Coding v1 uses WebSocket. Native Elixir calls implement the same
server boundary for local use and tests. HTTP is future work. This document
also states which rules the current code meets. A **MUST** rule is a
gate for the stated proof slice. It is not a claim about current code. A
paragraph marked **Proposed** records a design candidate, even when it uses
requirement language. It needs an ADR, a version or negotiated capability,
exact wire shapes, and a conformance case before a client can rely on it.

The words **MUST**, **MUST NOT**, and **MAY** state protocol requirements.
"Durable" means saved by the selected Jido Code Store under that Store's stated
failure model. The file profile now proves process restart. It does not prove
power loss or exactly once external effects.

[ADR 0004](../adr/0004-common-client-contract.md) sets one client contract.
[ADR 0017](../adr/0017-seigyo-protocol-and-live-progress.md) sets the local
Signal and Progress slice. [ADR 0009](../adr/0009-phoenix-client-transport.md)
sets the first remote transport proof. This specification gives their detailed
client rules. The [Signal schema catalog](signals.md#signal-schema-catalog)
is the sole list of wire shapes and limits.

## Release status

The [output rules](outputs.md) define supported content, retrieval, loss,
limits, and diagnostic privacy for the current coding server.

The local coding v1 profile has closed JSON data schemas, fixed Phoenix
Channel frames, capability discovery, typed errors, a standalone Elixir
WebSocket client, generated machine-readable fixtures, and a raw WebSocket
black-box verifier. The checked-in bundle is reproducible and detects drift
from the executable Seigyo catalog. It is not yet a published remote service
contract. External authentication and exact deployment quotas remain open.
The proposed Work and collaboration features need ADR decisions before a
client uses them. No proposed feature is implied by a v1 Signal.

## Engagement model

Jido Code manages an agent engagement on the Server. An engagement may have
several Work units over time. It may wait for a person, another agent, or a
timer. A Client sends intent, reads status, and answers a request for a
human decision. Jido Code controls Work and routes it to the Agent runtime. The
runtime owns committed Agent state. Jido Code manages resources, schedules,
execution retries, and recovery after an uncertain effect. This model can
serve coding and other agents. The current local v1 coding profile does not
yet have public Work identity or general agent support.

| Concept | Client meaning |
| --- | --- |
| Session | Shared context, access boundary, and ordered saved history. |
| Command | Client intent with a stable retry ID. Admission and outcome are separate facts. |
| Work | A Jido Code-owned execution unit. Jido Code may link child or scheduled Work; the Client sees safe status and links when they exist. |
| Update | An ordered saved fact that a Client can read after reconnect. |
| View | A bounded, coherent summary of the Session, active Work, and any pending human decision that the selected profile exposes. |
| Profile | Server-registered command, result, and activity shapes for one kind of agent engagement. |

The target engagement model has these invariants. They guide later profile
and wire decisions; they do not add v1 messages:

- **Keep Work visible.** A Client can recover the identity, status, and safe
  origin and parent links of accepted Work. It can tell when Work is active,
  waiting, settled, or uncertain. Each client-visible state change has a
  saved Session Update. The Client does not coordinate child Work.
- **Keep execution behind Jido Code.** A Client sends intent or a human decision.
  Jido Code manages the Agent runtime, tools, schedules, resource access, and
  effect recovery. A Client disconnect does not cancel accepted Work.
- **Separate admission from outcome.** A Receipt says that Jido Code accepted a
  Command. A saved Update gives the known result or uncertainty. Temporary
  Progress cannot settle Work.
- **Make recovery exact.** Jido Code uses stable IDs so a Command retry cannot
  start the same Work again. A Client replays saved Updates after its cursor
  and gets a coherent View. Jido Code does not skip a saved sequence that the
  Client cannot read.
- **Report uncertainty.** Jido Code does not report an unknown effect as success
  or failure. It blocks unsafe replay until evidence permits recovery.
- **Keep one meaning across profiles.** A profile can define its own inputs,
  results, and safe activity. It cannot weaken identity, access, retry,
  cursor, or outcome rules.

## Client loop

For a submitting Client, the loop has five steps: open an authorized Session,
submit a Command with a stable ID, keep its Receipt, read ordered saved
Updates, and read a bounded View. A client keeps its last applied Update
sequence. After a lost reply or connection, it retries the same Command ID
and data, then resumes the saved Updates. A Receipt proves admission. Only a
saved outcome settles the Command. A read-only Client can read an authorized
View and Updates
without submitting. Live delivery and Progress can make the display faster,
but neither changes the saved result.

The common contract fixes these meanings across profiles. A profile declares
its supported commands, result and event variants, View fields, resource
needs, and optional reads. Work is a Jido Code concept; its public shapes and
reads remain proposed. Coding, Schedules, placement, and shared editing add
specific capabilities. A client implements the selected profile and
capabilities. Each selected feature needs a closed schema and proof;
the Server must not send an unknown durable event to that client. Coding v1
records protocol version `1` and profile `coding` in each Session. Before
replay, the Server must prove that the client can read each retained event,
project it to a defined compatible form at the same sequence, or reject the
read. It cannot skip a sequence. The current local v1 coding shapes remain
fixed. This smaller common profile is a design target, not an available
remote version.

## Release gates

| Gate for the first remote profile | Present state |
| --- | --- |
| Identity and access | Local token binding, saved Session ownership, and two-principal isolation are implemented. External authentication and durable sharing are not fixed. |
| Wire and transport | Coding v1 has fixed WebSocket frames, closed current Signal schemas, and capability discovery. HTTP is not part of coding v1. Exact deployment quotas still need release fixtures. |
| Replay and failure | Ten closed Update variants, coherent View, typed errors, saved profile identity, restart recovery, per-variant disconnect replay, and bounded live resync have local proofs. A policy for old unreadable events remains. |
| Independent proof | The repository has a generated version manifest, Signal schemas, frame fixtures, WebSocket acceptance suite, and a raw black-box verifier. Publication packaging remains. |

Public Work, Schedules, Session listing, remote execution placement, general
agents, and collaboration need ADR and version decisions before each
capability is enabled. They do not all gate the first remote coding profile.

Released requirements need stable IDs, exact schemas, examples, and a
black-box conformance case. Each requirement ID must map to at least one
case. An external implementer should need only this document set, its
published schemas and fixtures, and a transport endpoint.

`Current coding v1` means the live WebSocket endpoint advertises and implements
the item and the Elixir client accepts it. `Draft` means a closed schema can
exist but the endpoint does not advertise it. `Proposed` means no compatible
wire contract exists. A public **Required coding v1** profile still needs the
remaining authentication and deployment policy decisions. The generated local
bundle already fixes current behavior, limits, errors, schemas, and frames.

## Documents

| Document | Purpose |
| --- | --- |
| [Model](model.md) | Session, Command, lifecycle, and profile rules |
| [Work](work.md) | Proposed async Work, subagents, Schedules, and Session listing |
| [Control plane](topology.md) | Proposed hosts, Workspace placement, Sandboxes, and multi-node rules |
| [Delivery](delivery.md) | Retry, replay, Progress, View, and restart rules |
| [Wire](wire.md) | Validation, identity, transport, and frame rules |
| [Messages and submission](messages.md) | Request, Reply, Event, correlation, and the preserved submission paths |
| [Processing and recovery](processing.md) | Retry keys, admission, completion, cancellation, and storage failure rules |
| [Collaboration](collaboration.md) | Proposed Users, Members, presence, and OT |
| [Signal shapes](signals.md) | The sole catalog of Signal types and data shapes |
| [Conformance](conformance.md) | Test scenarios and proof gates |
| [Implementation status](implementation.md) | Jido Code code map and open ADR decisions; not client requirements |
| [Coding v1 baseline](coding-v1-baseline.md) | Audited operation, Signal, client value, Update, test, and contradiction inventory |
| [TypeScript client proposal](client-design.md) | A possible independent reference client and harness UI |

Requirement IDs use the canonical `SEIGYO-CORE-nnn`, `SEIGYO-WIRE-nnn`,
`SEIGYO-WORK-nnn`, `SEIGYO-TOPO-nnn`, or `SEIGYO-COLLAB-nnn` forms. Test case
IDs use the `SEIGYO-TEST-nnn` form. Acceptance journey IDs use
`CODING-SESSION-nnn` and name the protocol test cases that they cover. A
released ID stays stable when text moves. A change to released behavior gets a
new ID and a version decision. Draft requirements can change until their
profile is accepted. A proposed rule does not become a client requirement
until its version, wire shape, and conformance case are fixed.
