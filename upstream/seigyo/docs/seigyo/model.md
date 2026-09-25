# Seigyo Protocol: Model

## Purpose and scope

A Jido Code Session is a server-owned client context with an ordered saved event
stream. It can outlive a client connection. In v1, a Command starts one Agent
request. The proposed Work model gives each execution unit its own identity.
A client can submit one command, leave, return, and read the saved result.
Two clients can observe the same Session. The server owns command admission
and shared state.
A client owns draft input, display state, and its last applied event cursor.
It does not own agent execution.

The current implementation is a **coding profile**. It binds each Session to
one Git Workspace, starts one Jido AgentServer with Jido AI state, and accepts
`submit_text`. The **common contract** in this document is the smaller
semantic boundary needed by a general agent. It does not require Git, a
Workspace, a model ID, a Jido AI Thread, tools, tokens, or reasoning text.
The current version 1 wire shapes still require a Workspace in a created
Session. A general agent cannot use those shapes without a new version or an
explicit ADR amendment. No client may read `workspace_id: null` as "no
Workspace" in version 1; it means "select the default Workspace".

The common contract contains Session and Command identity, admission, ordered
saved events, bounded reads, errors, and connection recovery. A profile
declares its authorized commands, safe View content, saved event variants,
and optional reads. The coding profile adds Workspace selection, model
choice, tools, and coding activity. A profile MUST NOT change common cursor,
retry, or Receipt meanings. A client selects a published profile and its
supported capabilities before it reads that profile's saved events.

### Owners and terms

| Term | Meaning and owner |
| --- | --- |
| Session | One shared client context and ordered event stream. Jido Code Server owns its lifecycle; Jido Code Store saves its identity and status. |
| Command | One client request for a state change or execution, with a stable client chosen ID. Server admits it through the Store. |
| Agent | The live worker. Jido AgentServer owns committed Agent state in the current coding profile. |
| Jido Code Store | Authority for command admission, Session revision, and ordered client events. |
| Agent checkpoint | Separate authority for committed Agent state. It is not one atomic commit with the Jido Code Store. |
| Workspace | A coding profile resource that names one continuing mutable tree. Server catalog owns its lease and placement. |
| Update | A saved EventRecord rendered as a client Signal. Its Session sequence is the replay key. |
| Progress | A temporary full snapshot of active work. It has no replay cursor. |
| View | A bounded projection of one coherent saved cut of Session and Agent state. |
| Trace | A bounded command activity read. Current fields are Jido AI specific. |
| Attach | A live connection's subscription to one authorized Session. It does not admit or cancel work. |
| User | A stable, authenticated principal. Server owns its identity and access checks. |
| Client | One attached app instance or tab. Its server-issued ID and presence end with the connection. |
| Member | A durable grant from a User to a Session with one role. It is distinct from a live Client. |
| Shared document | Optional Session text with its own authoritative revision and OT history. It is not the Agent transcript or a Workspace file. |

`jido_seigyo` owns portable Signal and error schemas. `jido_code_session`
owns Store transitions and ordered events. `jido_code_server` owns admission,
Agent joins, Workspace use, and the local protocol interpreter.
`jido_code_web` owns the current Channel and LiveView adapters. A future HTTP
adapter also belongs there. Every local transport calls `Jido.Code.Seigyo.Local`.
No transport owns a second queue, event log, or Session state machine.
`Jido.Signal.Bus` is not command ingress or replay authority.

## Required invariants

| ID | Rule |
| --- | --- |
| SEIGYO-CORE-001 | One accepted Command ID names one saved admission in the Store profile. The same ID in another Session conflicts. A retry cannot execute that command again. |
| SEIGYO-CORE-002 | A Receipt reports admission only. A saved outcome event reports result or uncertainty. Progress never settles a command. |
| SEIGYO-CORE-003 | Saved Update sequences are positive, contiguous, and increasing within one Session. `(session_id, sequence)` is an immutable replay key with one data value. |
| SEIGYO-CORE-004 | A client exit or connection loss has no effect on accepted work. Attach and detach change only connection state. |
| SEIGYO-CORE-005 | The client reads committed Updates from the Jido Code Store after a gap or reconnect. Live notices are only a delivery aid. |
| SEIGYO-CORE-006 | A View cursor and its content describe one coherent saved cut. The View cannot show an uncommitted Agent result as a settled result. |
| SEIGYO-CORE-007 | Every boundary validates the same closed, versioned message schema and value limits before use. Untrusted input cannot create atoms or executable terms, or be treated as modules, PIDs, references, or functions. The JSON transport has its own encoding limits. |
| SEIGYO-CORE-008 | The trusted caller identity, not any Signal field, controls open, submit, read, and attach access. |
| SEIGYO-CORE-009 | A profile can add rules, but it cannot weaken SEIGYO-CORE-001 through SEIGYO-CORE-008. |
| SEIGYO-CORE-010 | When shared documents are enabled, only the document authority orders accepted edits. A document revision never serves as a Session Update cursor. |
| SEIGYO-CORE-011 | Concurrent valid `SessionOpen` calls with one Session ID create at most one Session. After access checks, a repeat with the saved Workspace ID or null returns that Session; a different Workspace ID conflicts. |
| SEIGYO-CORE-012 | A Session does not end when a client disconnects or when a bounded View omits older messages. The View states when message content is omitted, and History and Updates remain the recovery sources. |

SEIGYO-CORE-001 through SEIGYO-CORE-008 and SEIGYO-CORE-011 through
SEIGYO-CORE-012 have local WebSocket proofs for the coding profile, including
disconnect replay of all ten advertised Update variants. The generated local
release bundle and raw WebSocket verifier cover the machine boundary.
SEIGYO-CORE-009 constrains every profile. SEIGYO-CORE-010 is a proposed
collaboration extension rule.

## Operations and results

A client sends `SessionOpen` and `Command` Signals for state changes. Reads
have typed, bounded inputs and no admission effect. Their results are
versioned Signals. The current local version 1 uses Server read operations;
it has no `ViewGet`, `UpdatesList`, `HistoryGet`, `TraceGet`, or
`WorkspaceChangesGet` request Signal. Coding v1 carries a read in the typed
Phoenix Channel RPC frame fixed by ADR 0019. A later transport can use another
frame, but it must apply the same argument schema and return the same result
and error meaning.

| Operation | Scope | Input | Success | Failure |
| --- | --- | --- | --- | --- |
| Open Session | Common meaning; current shape is coding v1 | `SessionOpen` | `SessionOpened` | `Failure` |
| Submit text | Coding v1 command | `Command` | `Receipt` | `Failure` before valid admission; rejected `Receipt` for a valid command that Server declines |
| Read View | Common cursor; profile content | Session ID | `View` | `Failure` |
| Read Updates | Common order; profile event variants | Session ID, exclusive cursor, page limit | `UpdatesPage` with closed `Update.data` items | `Failure` |
| Read History | Coding v1 projected conversation | Session ID, exclusive history cursor, page limit | `HistoryPage` | `Failure` |
| Read Trace | Coding v1 optional read | Session ID, command ID | `Trace` | `Failure` |
| Read Configuration | Coding v1 Session policy | Session ID | `SessionConfiguration` | `Failure` |
| Read Configuration History | Coding v1 saved policy history | Session ID, nullable exclusive revision cursor, page limit | `SessionConfigurationsPage` | `Failure` |
| Read Workspace Changes | Coding v1 current Git change set | Session ID | `WorkspaceChanges` | `Failure` |
| List Workspaces | Coding v1 authorized Workspace catalog | Empty arguments | `Workspaces` | `Failure` |
| Configure Workspace | Coding v1 host and runtime path binding | `WorkspaceConfigure` | `WorkspaceConfigured` | `Failure` |
| List Sessions | Later profile feature | Arguments and cursor to define | Versioned page shape to define | Versioned failure shape to define |
| Attach | Live transport; required for the first WebSocket proof | Session ID and caller context; transport control | Saved replay followed by live Updates and optional Progress | Transport rejection or `Failure` |

The coding Session extension adds configuration read, configuration-history
read, and change, fork,
queue-aware turn submit, steer, cancel, terminal Result read, and Attachment
upload operations. Its closed data schemas are in
[Signal shapes](signals.md#coding-session-evolution). These operations are in
the current capability manifest after the Server implements their lifecycle,
retry, access, and replay rules and the acceptance app proves them through
WebSocket.

A malformed or unknown Signal gets `Failure` before admission. A valid
Command that is busy, conflicts with Session state, or cannot reserve its
required resource gets a rejected `Receipt`. A failure after admission gets a
saved outcome `Update`. If a reply is lost, the client retries the same
Signal data and Command ID. It does not infer failure from a timeout. A
rejected Receipt did not save that ID; the same request can be tried again,
but a client must not silently alter its data under that ID.

`cancel_turn` is a current idempotent control mutation. A separate generic
cancel Command and Session close are not public version 1 operations. Stored
enums for those states do not make the operations available.

## Lifecycles

### Session

| State | Client meaning | Allowed version 1 action |
| --- | --- | --- |
| Absent | No saved Session with this ID. | Open with a new client chosen Session ID. |
| Open | Session exists and can admit work if its profile resource is ready. | Submit, read, and attach. |
| Closing | A future close command was admitted. | Read and attach; new work is rejected. |
| Closed | Close completed. Saved history remains readable under retention policy. | Read and attach only if authorized. |

Current public code creates `open` Sessions. It does not expose close. A
client disconnect does not change the lifecycle. The coding profile fixes
one Workspace ID at Session creation. A retry of `SessionOpen` with the same
Session ID and the same or null Workspace ID returns the saved Session. A
different Workspace ID conflicts. On retry, null does not run default
Workspace selection again. Current WebSocket tests prove sequential and
concurrent compatible opens. Crash recovery between Agent start and Store
create still needs a join and retry proof.

### Command

| State or result | Meaning | Saved client event now |
| --- | --- | --- |
| Rejected before admission | No CommandRecord was saved. A retry can be a new admission attempt with the same ID and data. | None |
| Accepted | The Store saved the CommandRecord and admission event. Agent work can start later. | `command_accepted` |
| Dispatched | The Agent request was linked to the saved command. | None; Store revision changes |
| Completed or failed | Server saved the known result. | `command_completed` or `command_failed` |
| Uncertain | Server cannot prove the Agent or external effect state. New conflicting work must wait for inspection. | `command_uncertain` |
| Reconciled | Later evidence can replace an uncertain state with a known result. | A later outcome event, if implemented |

`uncertain` is an unresolved state, not proof of failure and not permission
to run the effect again. Store transitions permit later resolution, but the
Server has no public reconciliation operation. A client keeps the Command ID
and reads new Updates. It MUST NOT create a replacement command that repeats
an unknown external effect without an explicit recovery decision.

A Result status is an execution outcome. `completed` means that execution
ended normally and the server saved the Result. It does not mean that a code
change is correct, verified, approved, published, or merged.
Result and Trace identify the pinned configuration digest and server-owned
tool profile. A Session saves its selected protocol version and profile.

### Connection

| State | Adapter action | Client action |
| --- | --- | --- |
| Detached | Keeps no claim on command work. | Keep last applied cursor. |
| Attaching | Authorize; register a bounded live buffer; read Store Updates after the client cursor. | Apply ordered Updates. Ignore duplicate replay keys. |
| Live | Deliver new saved Updates in sequence and optional temporary Progress. | Advance cursor only for saved Updates. |
| Resync | Send `ResyncRequired` if order or buffer safety is lost; stop claiming ordered live delivery. | Read Updates after own last applied cursor. If Store reports `gap`, get a fresh View. |

Attach does not imply Session open, command admission, or a protocol cursor
acknowledgement. Version 1 has no client acknowledgement Signal. The client
owns its cursor.

## Profile and Workspace extension points

**Proposed general profile:** a general agent supplies a server registered
profile ID, its state authority, supported command and event schemas, a View
projection, and optional reads. It may use no Workspace. Its common Session
and Command IDs, admission, replay, and error rules remain the same. A client
selects only an authorized profile ID; it cannot send a module name,
executable value, provider options, or raw Agent state. Profile data must
have closed schemas and bounded values. The Server owns the mapping from
profile ID to code.

The coding profile requires one Workspace ID for a Session. Null in current
`SessionOpen` selects the configured default. The Workspace catalog resolves
a safe summary for View. It pins placement version for a request and checks
the lease before tool work. The first local provider uses a borrowed Git
checkout and trusted host execution. It does not confine a shell to the
checkout. One active request per Workspace is a current coding profile rule,
not a common agent rule. A Workspace can outlive a Session. No wire Signal
used for Session work contains a raw root path, placement, lease, Agent
reference, PID, or credential. The separate authorized Workspace
administration Signals can carry the configured local host file path and
Sandbox runtime path. Future providers may use another location if they meet
the same catalog and lease contract.

The current v1 `SessionOpen`, `SessionOpened`, `View`, `Progress`, and `Trace`
shapes are coding and Jido AI shaped. **Proposed:** define a small common v2
profile with optional resource binding and separate coding extension types.
Do not change v1 null semantics or silently remove required v1 fields. The
version and exact profile selection shape need a new ADR before code changes.
