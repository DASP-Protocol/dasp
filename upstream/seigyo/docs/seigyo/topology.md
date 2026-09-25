# Seigyo Protocol: Control plane and placement

Status: Local BEAM placement and a local SmolBox microVM Workspace path are
implemented. Remote hosts are not implemented.

## Resource model

Jido Code is one logical control plane built from BEAM services. It admits client
requests, keeps Session and Work identity, records ordered Updates, manages
Workspace access, and selects execution placement. It can later run on more
than one API node after shared Store and ownership proofs. An API node is a
gateway. It cannot become a separate Session authority.

| Term | Identity and responsibility |
| --- | --- |
| Control plane | One logical Jido Code system with one client contract. Its storage profile pairs a Session Store, Workspace catalog, and Agent state authority; they are not one atomic Store. |
| Execution target | A registered capability set with a safe target ID. It maps to a BEAM host or an adapter to an external runtime; the physical locator is internal. |
| Workspace | One continuing mutable working tree with a stable Workspace ID. Its identity can remain when its placement is unavailable. It can outlive an Agent, Sandbox, host, or Session. |
| Placement | Internal binding of a Workspace to a target, provider, and location at one placement version. |
| Sandbox profile | A server-approved isolation mode, provider, and resource limit policy. |
| Sandbox | One execution environment with a stable Sandbox ID, target placement, lifecycle, and Workspace bindings. It may serve one Work run or remain available for later Work. Its owner and reuse policy must be explicit. |
| Agent runtime | A live Jido AgentServer or later worker that executes Work at a selected target. |

The default local profile keeps the control plane in one BEAM instance and
uses SmolBox for one offline microVM Sandbox per Session. The server checks the
worker version and an operator-pinned machine-image digest before it reports
the target as ready. It rejects Session admission when the target is not ready.
The `smolbox` profile has a VM fault and security boundary, with denied network
access. A trusted `beam_process` profile remains an explicit development
option. That profile is a supervised BEAM-process fault boundary only. The
local file Store allows one writable Jido Code server for a home. It is not a
multi-node control-plane Store.

The SmolBox target owns VM admission, lifecycle checks, and one managed
Workspace copy. It stages bounded tracked and unignored source files through
the SmolBox file API. It does not use a host mount. Repository tools and shell
commands run through the SmolBox execution API with the configured guest
Workspace as their working directory. After a mutating tool succeeds in the
VM, the target collects its bounded changed and deleted files back to the
borrowed host Workspace before it reports tool success. If collection cannot
be proved, the operation returns `unavailable` and the Workspace becomes
unavailable for later work. The Agent process and model orchestration remain
on the BEAM; untrusted Workspace effects run in the VM.

"Multiple servers" here means that one control plane can place Work on
several execution hosts and may later run several API nodes. Federation of
independent Jido Code control planes is a separate design. This extension does
not require `jido_cluster`.

## Session, Workspace, and Sandbox relationships

The current coding v1 Session has one primary Workspace. A later coding
profile may give a Session several named Workspace bindings. A Work request
pins each Workspace placement on first use and keeps that version for all
later effects on that Workspace. Before each effect, the control plane checks
the pinned lease and whether its provider can enforce read-only access. A run
with an unconfined shell or any unproved tool is write-capable. Shared read leases
need a provider that enforces read-only effects. The control plane selects
an execution target and any required Sandbox binding that can reach those
placements. A general Agent profile may need no Workspace. If no valid
placement exists, the Server rejects or waits under a defined Work policy.
It never silently runs a tool against a different tree. An effect that needs
several Workspaces must acquire its leases under one defined order or one
atomic reservation rule before that effect starts. The first remote
execution proof should place the Agent runtime and Workspace
provider on one target. Cross-target access needs a separate proof.

An execution target may run several Sandboxes. One Sandbox may bind several
named Workspaces when its provider supports that layout. A Sandbox may bind an
existing Workspace into its execution environment. If the Sandbox holds a
separate copy that can diverge, that copy has a new Workspace ID. A move may
retain the Workspace ID only after the control plane proves that the full
mutable state moved and the prior copy cannot receive
new writes. A copy of a borrowed tree gets a new Workspace ID. One Workspace
may be used by several Sessions, but its lease policy still controls
concurrent effects. A Sandbox provider owns its internal lifecycle. Its
public summary gives a stable ID, approved capability, and availability.
Sandbox teardown does not delete a borrowed Workspace or a managed Workspace
still referenced by an open Session or nonterminal Work. A managed Workspace
and a Sandbox each have their own
retention and cleanup policy. An existing Sandbox cannot be public for reuse
until its owner, access grants, binding limits, retention, and cleanup rules
are fixed. A Sandbox removal can remove only the state that its policy owns.

## Client boundary

A current coding v1 client selects one Workspace in `SessionOpen`; later
commands use that fixed Session binding. It reads safe targets and approved
Sandbox profiles with `execution_catalog`, and changes placement through the
revisioned Session configuration operation. In a later multi-Workspace profile,
a coding client may select stable Workspace IDs when its operation needs
them. It may select a server-approved Sandbox profile or an authorized
existing Sandbox ID when the profile offers that choice. A general profile may select
no Workspace. The authorized Workspace configuration operation carries one
local host file path and one Sandbox runtime path. Session and command
operations do not send a node name, PID, root path, container ID, host
address, provider module, or credential.
Each safe Sandbox profile reports a nullable `workspace_runtime_root`. This is
a guest-only path constraint, not a physical host locator. The SmolBox profile
reports `/workspace`; its configured runtime path can equal this root or be a
child of it.
An authorized client may list safe target summaries if the product
allows target choice. A summary reports a stable target ID, availability,
and capabilities. Server policy still makes the final placement decision.
Work Views can report the selected target ID, Sandbox ID, and a safe execution
mode, with a versioned schema. A Session View can contain bounded summaries
of active Work; it must not imply that all Work in the Session used one target.
Physical placement stays internal. A Sandbox list uses bounded safe summaries
and access checks.

The client attaches to a Session through any authorized API node. The node
reads saved Updates from the shared Session Store and forwards live Progress
from the execution target when available. Progress can be lost. A target
move does not reset the Session event cursor or change an accepted Command
ID. The client does not need a direct connection to the execution target.
A node may replay a saved outcome, but it returns `unavailable` for a View
if it cannot join that outcome to the required Agent state revision.

## Ownership and failure

Multi-node operation needs a shared durable Session Store, coordinated
Workspace catalog and Agent state authorities, and fenced lease or ownership
epochs for each Session and mutable Workspace. These records do not gain an
atomic commit merely because they use one storage backend. A process-local
Registry, ETS table, or Signal Bus cannot prove exclusive ownership across
targets. The Session Store rejects a stale Update commit. The Agent state
authority must reject a stale Agent write with a matching epoch or revision
rule; a Store fence alone does not protect that second authority. Each
Workspace provider checks the current fence before each Jido Code-mediated effect
that it can control. A prior effect may still run, and Jido Code cannot fence an external
editor or an escaped shell child on a borrowed checkout. On doubt, it blocks
Workspace reuse and reports uncertainty. The control plane records target
registration, health, capacity, drain state, and placement decisions. Health
loss alone does not prove that a process or external effect stopped.

If an execution target disappears during Work, the control plane keeps the
accepted identity, records uncertainty where effects may have run, and
blocks unsafe Workspace reuse until it has evidence. It may resume from a
committed checkpoint only under an explicit effect and placement recovery
rule. It never turns a lost heartbeat into permission to repeat a shell
command. The Store event sequence remains the recovery source for clients.

| ID | Requirement |
| --- | --- |
| SEIGYO-TOPO-001 | When an authorized client connects through another API node, it shall read the same saved Session Updates and command result; a View that cannot join the required Agent revision shall return `unavailable`. |
| SEIGYO-TOPO-002 | A Work request shall pin each Workspace placement on first use and keep its version for later effects on that Workspace. Before each effect, the control plane shall check its lease and execution target and any required Sandbox binding. |
| SEIGYO-TOPO-003 | If a target or lease is lost after an effect may have run, then the control plane shall block unsafe replay and Workspace reuse and expose an uncertain or unavailable state. |
| SEIGYO-TOPO-004 | A client shall use stable resource IDs and approved profile IDs; it shall not need physical host or Sandbox locator data. |
| SEIGYO-TOPO-005 | When a Sandbox copy can diverge from its source tree, the control plane shall assign that copy a distinct Workspace ID. |
| SEIGYO-TOPO-006 | When a client selects an existing Sandbox, the control plane shall check its access, availability, capabilities, and Workspace bindings before use. |

The current local proof implements TOPO-002 through TOPO-004 for one target
and a borrowed Workspace. It also checks an existing Session-owned Sandbox
binding as required by TOPO-006. `CODING-SESSION-012` proves trusted-host
placement, target-loss uncertainty, stable Workspace identity, and restart
recovery. `CODING-SESSION-018` proves default SmolBox selection, safe catalog
data, VM provisioning, and a turn without Workspace effects.
`CODING-SESSION-019` proves that an unavailable SmolBox target stays
discoverable and rejects Session admission. `CODING-SESSION-020` proves a
Workspace edit, tool evidence, normalized Result block, and change report
through the VM path. TOPO-001, divergent copies under TOPO-005, durable
Sandbox ownership evidence, automatic cleanup, reusable Sandbox authorization,
several targets, remote hosts, and multi-node API replicas need separate
proofs. Each future public message needs a versioned schema and conformance
fixture.
