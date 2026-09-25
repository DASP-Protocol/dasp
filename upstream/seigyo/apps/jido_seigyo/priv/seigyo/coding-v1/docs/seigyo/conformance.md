# Seigyo Protocol: Conformance

## Conformance scenarios and proof gate

Status: The development-only `jido_code_acceptance` app has the first real
WebSocket slice. It covers sequential and concurrent Session open, Workspace
binding conflict, and the simple reply from SEIGYO-TEST-001. It also covers the
duplicate and conflict behavior of SEIGYO-TEST-002, the
authorized typed live Progress, Progress reasoning redaction, durable cursor
separation, disconnect, and saved recovery paths of SEIGYO-TEST-003, the Trace
isolation and remote reasoning redaction, deterministic Workspace changes,
and patch bounds from SEIGYO-TEST-004, and the known model failure, its View outcome, next-turn recovery, and
uncertain-effect blocking parts of SEIGYO-TEST-005. It covers the
invalid-Session-ID and client command-input
parts of SEIGYO-TEST-006. Client-facing failures name `command_id`, `text`, and
`model`; rejected input creates no Update or History entry, and later valid
work still completes. It also covers
Update and History page replay, closed page-level identity and order rules,
page edges, in-flight outcome growth after an end page, and ahead cursors from
SEIGYO-TEST-007. It also proves disconnect replay of every advertised Update
variant. The generated release bundle fixes capabilities, operation mappings,
schemas, frames, limits, errors, and the conformance cases that prove each
operation and control. A mechanical acceptance test rejects catalog, role,
schema, proof, and UTF-8 byte-rule drift. A raw WebSocket verifier checks its
join, invalid-Session fixture, every advertised operation and control, and
unadvertised operation and event rejection against a live endpoint without
the typed client or server protocol modules.
It covers the subscribe-before-replay overlap and bounded loss recovery of
SEIGYO-TEST-008. A committed Update present in both replay and live delivery
reaches the client once. A deterministic pending-queue overflow sends one
typed `ResyncRequired`, does not advance the client cursor, and pauses live
delivery until the client replays and attaches again.
It covers stable two-client View reads, typed closed View content, a 16-turn
bounded message and outcome window, command status from dispatch through its
recent durable outcome, and a concurrent Store-Agent settlement cut from
SEIGYO-TEST-009. It also covers
invalid-credential rejection before
Seigyo Protocol channel join and cross-principal Session isolation from
SEIGYO-TEST-010. It covers the coding-profile discovery slice of SEIGYO-TEST-018:
the join publishes its operations, transport controls, request, result, and pushed Signal types,
and durable Update variants. Its operation error matrix fixes typed argument,
unknown Session, unknown Command, Failure, and rejected Receipt results for
the coding WebSocket operations. It also covers completed Session recovery under the
file profile from SEIGYO-TEST-013. A new WebSocket client reopens the Session,
replays its saved result, retries the first Command, and continues with a new
turn after the server stack restarts. An in-flight Command recovers as
`uncertain`, keeps its retry position, appears in a safe redacted View, and
blocks new Workspace work after the same restart. Every scenario runs the shared
`jido_seigyo` through the real WebSocket and MockLLM path. Focused client
and Web wire tests cover malformed envelopes that the public API cannot
create. The Web input gate fixes errors for source, CloudEvents version,
envelope ID and shape, data version and shape, Signal type, and Signal size.

The first coding story also proves two ordered turns through the public
History read, one tracked file edit, an inspect-edit-verify tool sequence, and
a second-turn correction through Trace and WorkspaceChanges. It also proves
that one active coding Command owns the Workspace: a second client gets a
rejected Receipt with no Update, History, Trace, or model work, and the same
Command ID and input can be accepted after the first Command settles.
CODING-SESSION-006 proves the mixed outcome order: a successful turn followed
by a failed turn keeps the successful `last_result_command_id`, while
Updates, History, Trace, and recent outcomes remain joined to the correct
Command IDs. CODING-SESSION-008-LONG exceeds the bounded View message window,
reconnects with a new WebSocket client, reads complete History and Updates,
and continues the same Session. The View states that its message window is
truncated.
Scenario modules do not inspect the temporary checkout, Store, Server, ETS,
or MockLLM. Harness setup can seed the checkout and model plan, but client
values supply the result evidence.

The suite treats `Jido.Seigyo.Client` and the Jido Code server as one public
integration surface. It uses only published client operations for assertions
about client behavior. A fixture adapter can prepare users, Sessions, clocks,
model replies, and process faults.
It cannot supply a client result or read private Store state as the sole proof
of a client assertion. Coding v1 runs every case through WebSocket. A future
transport can reuse the case IDs when it supports the same operation. Native
Elixir tests can give more implementation evidence, but they cannot replace a
WebSocket case.
The suite publishes canonical JSON inputs, expected outputs, state traces, a version and
capability manifest, and fixture setup instructions. Each case states whether
it is required by the base profile or an extension.
For the current coding WebSocket profile, cases 001 through 010, 013, and 018
through 020 describe the proof. Cases 011, 012, 014 through 017, and 021
through 023 gate later profiles. Case 008 applies to live attach. A released
manifest must name its exact case set.

| Case ID | Scenario | Requirements | Required assertion |
| --- | --- | --- | --- |
| SEIGYO-TEST-001 | Open and simple reply | SEIGYO-CORE-001, SEIGYO-CORE-002, SEIGYO-CORE-006, SEIGYO-CORE-011 | Sequential and concurrent open retries create one Session; a null Workspace ID retry returns the saved binding; a different binding conflicts. Accepted Receipt points to the saved admission event; outcome Update and coherent View show the result. |
| SEIGYO-TEST-002 | Duplicate and conflict | SEIGYO-CORE-001 | Sequential or concurrent use of the same Command ID and data returns the original position, even when JSON key order or envelope ID changes. Concurrent changed data or another Session conflicts; the model runs once. |
| SEIGYO-TEST-003 | Disconnect and recovery | SEIGYO-CORE-002, SEIGYO-CORE-004, SEIGYO-CORE-005 | Progress may arrive and vanish; accepted work continues. WebSocket detaches, replays from its saved cursor, and continues with live Updates. The client reads the saved outcome and View. |
| SEIGYO-TEST-004 | Tool loop | SEIGYO-CORE-002 | Tool runs once in the selected Workspace; saved coding activity exists when that extension is implemented; Trace and View are bounded. |
| SEIGYO-TEST-005 | Failure and uncertainty | SEIGYO-CORE-002 | Failed known work gets a failed event; unknown effect state gets uncertain and blocks conflicting coding work. No Progress becomes a result. |
| SEIGYO-TEST-006 | Bad input | SEIGYO-CORE-007, SEIGYO-WIRE-001, SEIGYO-WIRE-002 | Wrong type, version, source, shape, ID, or size fails before admission and before model use. All accepted client Signal types use `jido.client.`. Source does not grant identity. |
| SEIGYO-TEST-007 | Replay and retention | SEIGYO-CORE-003, SEIGYO-CORE-005, SEIGYO-WIRE-003 | Cursor 0, duplicate event before and after client restart, page edge, ahead cursor, and a new event after an end page have defined results. Page items and live Updates use the same closed Update data; each page item matches the page Session ID. A normal View read does not skip unseen Updates. Test a Store `gap` when retention is enabled. A client without one stored event variant gets a stable failure, with no skipped sequence or cursor advance. |
| SEIGYO-TEST-008 | Attach race | SEIGYO-CORE-003, SEIGYO-CORE-005 | Two clients attach while an event commits; each applies every saved sequence once. Buffer overflow causes ResyncRequired and Store replay. |
| SEIGYO-TEST-009 | View race | SEIGYO-CORE-006 | An Agent result and Store outcome commit during View construction; returned View is a coherent cut or unavailable. |
| SEIGYO-TEST-010 | Identity | SEIGYO-CORE-008 | Two principals test permitted open, read, and submit; WebSocket also tests attach. A denied caller learns no private data. Changing Signal `source`, path, or topic does not change access. |
| SEIGYO-TEST-011 | Collaboration extension | SEIGYO-CORE-008, SEIGYO-COLLAB-001, SEIGYO-COLLAB-002, SEIGYO-COLLAB-003, SEIGYO-COLLAB-004 | Two Users and several Clients per User see one author's command, Progress, and outcome. Attribution survives restart. A viewer cannot submit or edit; grant removal closes live access. |
| SEIGYO-TEST-012 | OT extension | SEIGYO-CORE-010, SEIGYO-COLLAB-005, SEIGYO-COLLAB-006 | Concurrent insert and delete converge, including Unicode offsets; duplicate and stale operations, lost replies, restart, history expiry, and snapshot resync preserve unacknowledged input. |
| SEIGYO-TEST-013 | Restart | SEIGYO-CORE-001, SEIGYO-CORE-002 | Completed work and retry position survive process restart under file profile; in-flight work becomes uncertain without effect replay. |
| SEIGYO-TEST-014 | General profile | SEIGYO-CORE-009 | A non-coding Agent runs without Git, Workspace, model, or Jido AI fields after the profile version is defined. |
| SEIGYO-TEST-015 | Work graph extension | SEIGYO-WORK-001, SEIGYO-WORK-002, SEIGYO-WORK-003, SEIGYO-WORK-004, SEIGYO-WORK-008, SEIGYO-WORK-009 | Closed Command kinds with zero, one, and several Work units keep one saved intent. A duplicate returns links present at read time; a later link arrives in an Update and retry creates no second effect. A client disconnects and recovers state; an Agent repeats one child request key and gets the same child. Parent links, ordered Updates, and uncertain effect rules hold. |
| SEIGYO-TEST-016 | Schedule extension | SEIGYO-WORK-005, SEIGYO-WORK-006 | Duplicate timer wakes and restart create one occurrence; a revoked actor gets one saved skip and no Work. Each trigger uses only its declared timing fields. |
| SEIGYO-TEST-017 | Session list extension | SEIGYO-WORK-007 | Two clients page an authorized list while Session activity changes. Results follow the declared order and concurrent-change behavior; a client can refresh and then read authoritative View and Updates. |
| SEIGYO-TEST-018 | Error and capability manifest | SEIGYO-CORE-007, SEIGYO-CORE-008, SEIGYO-WIRE-004 | Each published operation has exact Failure or rejected Receipt cases, safe code and field values, and transport status mapping. Discovery names only operations, Signal types, and Update variants the endpoint supports. |
| SEIGYO-TEST-019 | Durable mutation replay | SEIGYO-CORE-003, SEIGYO-CORE-005 | A repeated Session or Workspace Mutation ID and the same input return the original result after later changes and restart. Changed input conflicts and creates no second mutation. |
| SEIGYO-TEST-020 | Cursor delivery integrity | SEIGYO-CORE-003, SEIGYO-CORE-005, SEIGYO-WIRE-003 | Update pages bind to the requested cursor, terminal Updates identify their Result, and acknowledged live delivery advances only after the client applies and acknowledges one Update. |
| SEIGYO-TEST-021 | Two execution targets | SEIGYO-TOPO-002, SEIGYO-TOPO-004, SEIGYO-TOPO-005, SEIGYO-TOPO-006 | Two registered targets use distinct Workspaces. A Work request keeps the first placement version for later effects on that Workspace; each effect checks its lease. An optional Sandbox is authorized before use. A divergent copy gets a new Workspace ID. An unconfined shell never gets a shared read lease. No physical locator is exposed. |
| SEIGYO-TEST-022 | Host loss and recovery | SEIGYO-TOPO-003 | A host disappears during an effect. The command remains accepted; the Workspace is blocked until recovery evidence exists; no effect is repeated from a retry. |
| SEIGYO-TEST-023 | API node handoff | SEIGYO-TOPO-001, SEIGYO-TOPO-002, SEIGYO-TOPO-003 | Two API nodes submit the same Command ID at once and create one admission. A stale Session owner cannot append an Update, and a stale Workspace holder cannot pass a provider fence. A client reads and attaches through another node and gets the same saved sequence. A View joins the saved Agent revision or returns `unavailable`. This case requires shared authorities and fencing proof. |

Run common call and replay assertions through the coding v1 WebSocket with two
client processes. A future transport reuses the common assertions and adds
its own delivery proof. JSON cases round trip every Signal and
reject unknown attributes and nested keys. Normalize generated IDs when
comparing separate runs. Compare replayed Updates by Session ID, sequence,
and data, not envelope ID. Progress timing and count may differ. The first
remote proof passes only when admission, read results, cursor behavior, error
codes, and identity have the same meaning on each path. WebSocket also proves
attach recovery.
The general profile, Work, placement, coding activity, and collaboration
scenarios gate their later slices, not the first coding transport proof.

## Coding Session journey

The acceptance app specifies these coding cases as complete client journeys.
CODING-SESSION-007 through CODING-SESSION-020 are active protocol proofs.
Each scenario uses only `Jido.Seigyo.Client` for observations.
The test bodies and case data define the next TDD targets.

| Journey ID | Scenario | Main proof |
| --- | --- | --- |
| CODING-SESSION-007 | Versioned Session configuration | Revision checks, pinned active configuration, durable model changes, pending changes, portable digests, saved protocol and tool-profile identity, ordered configuration history, and Result and Trace provenance across restart. |
| CODING-SESSION-008 | Queue, steer, and cancel | Separate retry identities, ordered queued turns, one-time steering, and evidence-based cancellation. |
| CODING-SESSION-008-LONG | Long Session continuation | A bounded View declares omitted messages; a new client reads full History and Updates and continues the same Session after many turns. |
| CODING-SESSION-009 | Long context compaction | Immutable Session history, new context revisions, durable compaction facts, and Result attribution. |
| CODING-SESSION-010 | Fork and side chat | Committed lineage, independent child state, isolated coding snapshot, and read-only side chat default. |
| CODING-SESSION-011 | Attachments | Ordered bounded chunks, verified commit, ready-only turn use, and authorized immutable reuse. |
| CODING-SESSION-012 | Workspace execution policy | No host paths, pinned execution policy, uncertain effect handling, and stable Workspace identity across placements. |
| CODING-SESSION-013 | Normalized Result | One atomic saved Result, stable restart reads, hidden subagents, closed result blocks, pinned execution revisions, and bounded aggregate evidence. |
| CODING-SESSION-014 | Provider parity | One coding job has the same model identity, tool evidence, markdown Result, Trace, and View through OpenAI Chat and Anthropic Messages wire formats. |
| CODING-SESSION-015 | BEAM client fault isolation | One client process fails during active work; another Session completes, and a new client resumes the first Session without a duplicate Result. |
| CODING-SESSION-016 | Workspace catalog | An authorized client lists one Workspace, reads its host and runtime paths, changes its versioned configuration, opens a Session on it, and cannot list or open it as another principal. |
| CODING-SESSION-017 | Coherent current-head fork | Version 1 accepts a fork only at the current committed head and rejects a historical hybrid. |
| CODING-SESSION-018 | Default local SmolBox placement | The client sees one safe VM profile, a Session gets a stable Sandbox ID, and a no-tool turn completes after Sandbox provisioning. |
| CODING-SESSION-019 | Unavailable SmolBox admission | An unavailable VM target stays visible in discovery and Session open fails before Agent work starts. |
| CODING-SESSION-020 | SmolBox Workspace effect | A coding tool edits the managed VM copy, the Result reports Workspace changes, and the client reads the VM change set through Seigyo. |

`SEIGYO-TEST-019` proves durable Session and Workspace mutation replay after
later changes and restart. `SEIGYO-TEST-020` proves request-cursor binding,
terminal Result correlation, and explicit live delivery acknowledgement.

## Jido Code integration proof

Run native semantic cases first, then the same assertions through the
WebSocket adapter. The following setup gives extra evidence for Jido Code's
internals.

Use `Jido.AI.Test.MockLLM` as a loopback model server for the coding profile.
Keep real ReqLLM, Jido AgentServer, Server, Store, and Workspace tools. Use a
temporary Git checkout and isolated state. No test may need an external model
account or API key. The mock script must account for all requests and
replies. Use wait points and bounded event waits, not fixed sleep intervals,
to control races. The native and WebSocket drivers call only the public
protocol operations for client results. Lower-level package tests may
inspect Store state and mock reports. An acceptance scenario must not use that
evidence. It must read all result evidence through the Seigyo Protocol.

For the WebSocket suite, ExUnit starts one supervised acceptance runtime per
test. The runtime owns its token, temporary Git checkout, Store, MockLLM,
Server stack, network listener, and client processes. It monitors required
components and cleans up all resources when the test stops. New scenarios can
start more clients in the same runtime or stop one named component to test
public recovery and failure behavior. Tests do not change global application
environment values.
