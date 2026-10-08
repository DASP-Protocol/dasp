# Capability discovery

**Status: draft-01, unreleased.** This document defines an abstract setup
contract. It does not define transport frames or a complete interoperable
binding.

The contract identity is
`https://dasp-protocol.github.io/dasp/contracts/capability-discovery`. Its
version is `draft-01`.

## Scope and contract boundary {#dasp-disc-001}

Requirement group **DASP-DISC-001**.

Capability discovery is an optional setup subprotocol. It is not a DASP core
operation and it is not a DASP extension. It adds no core message type, field,
cursor, retry rule, admission rule, update, outcome, or session rule.

The peers MUST select and authenticate one exact discovery-capable binding
mapping before the first discovery operation. The selected setup tuple MUST
bind the binding identity and version, discovery identity and version,
immutable content references, peer identities, selected limits, and optional
features. Discovery MUST finish before the peers confirm the normal DASP core,
profile, binding, and extension selection for a session.

Discovery is read-only, non-durable, and limited to one authenticated
connection. It describes one actor. It does not create a session or save a
DASP fact. A binding MUST NOT map a discovery operation to a core CloudEvent
type.

This document defines operation names, control semantics, failures, snapshot
behavior, and resource semantics. Each binding mapping MUST define framing,
request and reply correlation, transport encoding, authentication, timeouts,
and connection-close behavior. A mapping MUST preserve all abstract behavior
in this document.

## Meaning of discovery {#dasp-disc-002}

Requirement group **DASP-DISC-002**.

An advertised capability means only that the host describes one command for
one actor, one resolved advertised view, and one immutable snapshot. It does
not do any of these actions:

- Select the actor profile.
- Authorize a command.
- Grant access.
- Prove current command availability.
- Promise later admission or execution.

The client MUST support the actor's exact discovered profile contract before
it can assert that profile tuple in `session.open`. The host can still reject
an advertised command because of current policy, actor state, limits, or
profile rules.

The contract uses these separate capability sets:

| Set | Owner and meaning |
| --- | --- |
| Profile capability universe | The exact profile defines all valid command capabilities and marks each one as required or optional. |
| Actor effective set | All required capabilities plus the optional capabilities that this actor activates. |
| Advertised view | A disclosure projection of the actor effective set for one authenticated context. |

An actor and an advertised view MUST NOT create a capability outside the
profile universe. An advertised view MUST NOT activate an optional capability.
The exact capability identity is the exact profile URI, exact profile version,
and command name. Implementations MUST compare all three parts exactly.

## Terms and identities {#dasp-disc-003}

Requirement group **DASP-DISC-003**.

| Term | Meaning |
| --- | --- |
| Start identity | Client value that makes the first list request idempotent on one connection. |
| Advertised-view selector | Optional typed opaque client value that requests one disclosure view. |
| Resolved-view identity | Opaque host value for the view that the host resolved. |
| Snapshot identity | Opaque host value for one immutable discovery boundary. |
| Continuation token | Opaque host value that identifies the next page in one snapshot. |
| Resource identity | Opaque host value that identifies one exact resource representation in one snapshot. |
| Actor profile descriptor | Exact profile URI and version, immutable content reference, and compatible core contract information. |

These identities are references. They are not authorization evidence. They
MUST NOT carry credentials, grants, policy, or authority. A host-issued
identity MUST be bound to the authenticated client context, actor, actor
profile tuple, discovery contract version, resolved view, snapshot, and
operation where applicable. It MUST expire, resist guessing and forgery, and
contain no sensitive clear text.

A server-issued identity MUST also bind the normalized request parameters that
affect its result. A continuation token is not a DASP update cursor. A snapshot
or resource identity is not a JSON Schema `$id`. A representation digest is
not a resource identity. One identity MUST NOT substitute for another.

## Operations {#dasp-disc-004}

Requirement group **DASP-DISC-004**.

The companion contract has this closed operation family:

| Operation | Purpose |
| --- | --- |
| `capabilities.list` | Reveal the actor profile and read bounded capability summary pages. |
| `capabilities.get` | Read details for selected exact capability identities. |
| `capabilities.resource.read` | Read one exact schema resource representation. |
| `capabilities.snapshot.release` | Release retained snapshot state early. |

An implementation MUST NOT use successful support for one operation as proof
of support for another operation. A binding mapping MUST preserve the
operation identity and request correlation. The binding mapping MUST reject or
close on an operation before exact mapping selection and authentication. It
MUST NOT process that operation as core traffic.

## Summary enumeration {#dasp-disc-005}

Requirement group **DASP-DISC-005**.

The first `capabilities.list` request MUST contain a start identity, actor
identity, selected discovery limits, and an optional advertised-view selector.
A continuation request MUST use only the opaque continuation token and binding
correlation data.

The first successful reply MUST do all of these actions:

1. Return the actor's exact profile descriptor.
2. Create one immutable snapshot.
3. Return the snapshot identity and opaque resolved-view identity.
4. Return a bounded first page in deterministic order.
5. Return a completion value and, when incomplete, one continuation token.

Every page MUST identify the same actor profile tuple, snapshot, and resolved
view. The order MUST be the command name compared by UTF-8 bytes within the
exact profile tuple. The host MUST NOT add, remove, or reorder items in a
snapshot after the first successful reply.

Each nonterminal page MUST contain at least one summary that was not in an
earlier page. It MUST contain one continuation token. The terminal page MUST
state that enumeration is complete and MUST omit the token. The host MUST NOT
silently truncate a page or the complete enumeration.

A complete enumeration MUST contain every capability in the resolved
advertised view. The host does not have to return a total count. A client MUST
reject continuation loops, duplicate pages, duplicate capability identities,
mixed profile tuples, mixed snapshots, mixed views, changed continuation
parameters, and local page or byte limit overruns. The client MUST discard an
incomplete enumeration.

## Idempotency and snapshot lifecycle {#dasp-disc-006}

Requirement group **DASP-DISC-006**.

The start identity is scoped to one authenticated connection and one normalized
first-list request. A repeated valid start request MUST return the same logical
snapshot and first page while the snapshot is retained. A repeated valid
continuation request MUST return the same logical page while it is retained.

The snapshot covers summaries, command details, resource manifests, and exact
resource bytes. The host can implement this as a logical stable view. It does
not have to copy all data. Reading the terminal page MUST NOT release or change
the snapshot.

A snapshot is read-only, non-durable setup state. It MUST NOT survive a
connection loss. A client MUST start a new enumeration on a new connection and
MUST NOT reuse a start identity, snapshot identity, continuation token, or
resource identity from the old connection.

The host MUST retain a successful snapshot for the selected retention period,
unless current disclosure stops access or the client releases it. Capacity
pressure MUST NOT cause early eviction during that promise. After retention
ends, a valid current-context snapshot operation MUST fail with
`stale_snapshot`. An unknown, forged, or foreign-context identity MUST fail
with masked `unavailable`.

## Selective details {#dasp-disc-007}

Requirement group **DASP-DISC-007**.

A `capabilities.get` request MUST identify one retained snapshot and a bounded,
nonempty list of exact capability identities. Each identity MUST use the
snapshot profile tuple.

The operation is atomic. If all requested identities are available in the
snapshot, the host MUST return all requested details once and in request order.
If one identity is not available, the host MUST return no detail. The failure
MUST NOT identify the failed item, its batch position, a count, the snapshot,
or the view.

A detail can contain bounded presentation data and resource descriptors. It
does not change the capability set or prove that a later command will be
admitted.

## Resource reads {#dasp-disc-008}

Requirement group **DASP-DISC-008**.

A `capabilities.resource.read` request MUST identify one retained snapshot and
one opaque resource identity from a returned detail manifest. The success
reply carries the exact ordered representation after transport decoding. A
binding can carry it as one body, a stream, or bounded ordered chunks. It MUST
not carry it through DASP portable event JSON.

The response MUST identify the media type and exact decoded byte length. If a
representation digest is present, it MUST identify its algorithm and media
type and cover all exact decoded bytes. Resource identity, representation
digest, schema `$id`, and snapshot identity are separate identity domains.

Resource identities are not URLs or file paths. A client or host MUST NOT load
a URI, file, code module, vocabulary, or format only because its name occurs
in a selector, resource identity, schema keyword, or annotation.

## Snapshot release {#dasp-disc-009}

Requirement group **DASP-DISC-009**.

`capabilities.snapshot.release` asks the host to release one retained snapshot
before its retention period ends. Release is idempotent. A repeated valid
release in the same authenticated context MUST return the same logical
confirmation. The host MAY keep a bounded release record until the original
retention period ends.

After release, the host MUST NOT return page, detail, or resource data from the
snapshot. A valid same-context read from a released snapshot MUST use
`stale_snapshot` while the bounded release record exists. An unknown identity
after that record expires MUST use masked `unavailable`. Release does not
change an actor, profile, session, admitted command, saved update, outcome, or
DASP cursor.

## Advertised views and current disclosure {#dasp-disc-010}

Requirement group **DASP-DISC-010**.

An advertised-view selector is optional, typed, bounded, and opaque. Its type
is an identifier. The host MUST NOT fetch or execute its type URI. The selector
MUST NOT contain a credential, grant, policy document, or authority claim.

The host MUST resolve the selector only inside the maximum disclosure set that
its external security system supplies for the authenticated context. The host
MUST return an opaque resolved-view identity. It MUST NOT echo the selector or
disclose policy details.

The host MUST perform a fresh disclosure check before every page, detail,
resource, and release response. The check does not change snapshot contents.
If current disclosure contracts, the host MUST stop later reads with masked
`unavailable`. It MUST NOT replace data with a new snapshot or a smaller page.
The client MUST discard every incomplete enumeration and incomplete resource
closure from that snapshot.

Absent, inaccessible, undisclosed, forged, foreign-context, wrong-actor, and
wrong-version targets MUST use the same masked `unavailable` shape.

## Limits and progress {#dasp-disc-011}

Requirement group **DASP-DISC-011**.

The selected discovery-capable binding mapping MUST state finite limits for:

- Capability summaries in the complete advertised view, items in a page, and
  capability identities in a detail request.
- UTF-8 bytes in each control document and each presentation value.
- Bytes in one exact resource representation.
- Resources and exact bytes in one schema closure.
- Bytes in each opaque client or host value.
- Live snapshots in one authenticated context.
- Snapshot retention time.

The applied limit is the value selected by the authenticated mapping. A peer
MUST enforce it before large allocation or processing where possible. A client
MAY apply stricter local limits and stop.

`view_items` is the maximum number of capability summaries in the complete
resolved advertised view. It does not require the host to disclose a total
count. The host MUST enforce it before it returns the first successful page.
A larger resolved view MUST cause `view_too_large`, with `view_items` in limit
detail when limit detail is present.

One item that cannot fit MUST cause `item_too_large`. The host MUST NOT
truncate the item, truncate the view, or return an empty continuation loop.
Lack of live snapshot capacity MUST cause `snapshot_capacity`. The host MUST
NOT evict a retained snapshot early to satisfy another start request.

## Failures {#dasp-disc-012}

Requirement group **DASP-DISC-012**.

The abstract contract has these closed failure codes:

| Code | Meaning | Same-operation retry |
| --- | --- | --- |
| `unsupported_contract` | The peer cannot select the exact discovery contract or mapping. | Only after configuration or selection changes. |
| `invalid_request` | A known operation has an invalid control shape or value. | No, until the request changes. |
| `unavailable` | Masked absence, access refusal, or foreign identity. | A local policy can start a new attempt. No identity detail is available. |
| `invalid_continuation` | A valid current-context token is used for the wrong operation or sequence. | No, until the request changes. |
| `stale_snapshot` | A valid current-context snapshot is past its retention period. | Start a new enumeration. |
| `request_limit` | A request exceeds a selected count or control-byte limit. | Use a smaller valid request. |
| `item_too_large` | One disclosed item cannot fit the selected item or page limit. | Only after selected limits change. |
| `view_too_large` | The resolved view has more capability summaries than selected `view_items`. | Only after the view or selected limits change. |
| `snapshot_capacity` | The host cannot retain another snapshot under the selected live-state limit. | Yes, after capacity becomes available. |
| `resource_unavailable` | An established disclosed resource cannot currently be served as declared. | As stated by the binding mapping. |
| `contract_violation` | A peer produced data that violates the selected contract. | The receiver stops the affected discovery flow. |

Masked `unavailable` MUST NOT echo an identity, selector, count, snapshot,
view, reason, or failed batch position. The other limit details can be returned
only after the host establishes access to the target. A failure MUST NOT be
used as a DASP command outcome or receipt.

## Actor profile and session assertion {#dasp-disc-013}

Requirement group **DASP-DISC-013**.

Each actor has one exact profile URI and version for its lifetime. Its profile
descriptor MUST also contain an immutable profile content reference and
compatible core contract information. Discovery reveals this descriptor. It
does not offer a list of profile choices.

Each `session.open` for the actor MUST repeat the same profile URI and version
as an assertion and compatibility guard. The host MUST compare the tuple with
the actor's immutable tuple before it creates or attaches the session. A
mismatch MUST fail and MUST NOT create or attach a session.

More than one session can bind to one actor. Each session keeps its own ordered
history and cursor. All such sessions use the actor's one profile tuple. An
incompatible profile change requires a new actor identity unless a future
explicit migration contract defines another safe transition.

An explicit discovery refresh creates a new snapshot under current disclosure.
It MUST keep the same actor profile tuple. It MUST NOT change an existing
session's profile, saved protection floor, command admission, retry facts,
history, outcome, or update cursor. Version 1 defines no push invalidation or
capability-delta channel.

If a peer does not support the exact discovery contract, a client MAY continue
only when it has exact configured knowledge of the actor profile and explicit
local policy permits operation without discovery. Silence or a timeout MUST
NOT cause a weaker fallback. The client MUST NOT guess a profile.

## Profile interaction and actor boundaries {#dasp-disc-014}

Requirement group **DASP-DISC-014**.

A profile MAY define a thread or episode as application state that groups
related commands in one session. Each command keeps its own `command_id`.
The group uses the session's one ordered history and cursor. It MUST NOT have
independent core admission, retry, replay, recovery, or cursor rules.

The command is the core unit that is closest to a turn. A profile MAY define
`turn_id` only when that value has meaning that differs from `command_id`.
A profile MUST NOT add a duplicate durable command identity.

A sub-actor MUST be one of these forms:

1. An opaque implementation detail of the parent actor profile.
2. A unique actor reached through an explicit profile-defined handoff.

The second form requires independent child discovery, profile confirmation,
disclosure checks, admission, and a new session. The child MUST NOT join the
parent session or share its history or cursor. Profile data can link or
correlate parent and child work. Authority and discovery state MUST NOT move to
the child automatically.

## Untrusted data and conformance boundary {#dasp-disc-015}

Requirement group **DASP-DISC-015**.

Names, labels, descriptions, schema annotations, defaults, examples, selector
values, and profile metadata are untrusted, non-normative data. Each value MUST
be bounded by the selected UTF-8 byte limit. A client MUST keep this data inert
until the use context applies suitable validation and escaping. It MUST NOT
place discovered text directly into executable agent instructions, tool
definitions, code, shell text, HTML, Markdown, terminals, or logs.

Abstract-contract checks can establish agreement with this document. They do
not establish binding interoperability. A conformance claim MUST identify the
exact discovery contract, binding mapping, content references, limits,
authenticated context assumptions, implementation versions, executed cases,
skipped cases, and connection boundary. A complete binding mapping needs
independent runtime evidence for exact framing, correlation, authentication,
timeouts, close behavior, and streamed resource bytes.
