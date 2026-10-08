# Schemas and downloads

Draft-01 uses JSON Schema 2020-12. The core schema defines generic event
structure. Application profiles validate their own payloads. The optional
[capability-discovery contract](../specification/capability-discovery.md)
uses separate setup control documents. These documents are not core
CloudEvents.

| Artifact | Purpose |
| --- | --- |
| [Core envelope schema](../../specification/draft-01/envelope.schema.json) | The 14 core event types and their data shapes |
| [Capability-discovery control schema](../../specification/draft-01/capability-discovery.schema.json) | Closed requests, replies, failures, limits, summaries, details, resource descriptors, and release documents |
| [Capability-discovery example](../../specification/draft-01/examples/capability-discovery.json) | A complete progressive flow from first list request through release |
| [Agent input schema resource](../../specification/draft-01/examples/capability-schemas/agent-ask-input.schema.json) | A compound input contract with full JSON Schema 2020-12 features |
| [Shared context schema resource](../../specification/draft-01/examples/capability-schemas/shared-context.schema.json) | A required resource in the compound schema closure |
| [Boolean schema resource](../../specification/draft-01/examples/capability-schemas/allow-any.schema.json) | A valid JSON Schema resource with a Boolean root |
| [Capability-discovery conformance fixture](../../conformance/fixtures/capability-discovery.json) | Recorded scale, paging, identity, resource, profile, and failure inputs shared by both clients |
| [Counter profile schema](../../specification/draft-01/examples/counter-profile.schema.json) | Illustrative input, state, output, and progress payloads |
| [Example events](../../specification/draft-01/examples/counter.json) | At least one event of each core type |
| [Artifact manifest](../../specification/artifacts.json) | SHA-256 digests for the current schema, example, resource, and fixture bytes |

## Read the discovery artifacts

A discovery-capable binding first carries an authenticated setup probe or
offer. This envelope selects the exact binding mapping, discovery contract,
versions, content references, peer identities, and limits. The abstract
contract does not define the envelope bytes. After selection, the mapping can
carry the four discovery operations before normal DASP profile confirmation
and `session.open`.

The first `capabilities.list` reply reveals the actor's one immutable profile
descriptor and the first bounded summary page. If an actor has hundreds or
thousands of capabilities, the host does not return one large catalog. The
client follows opaque continuation tokens in one stable snapshot until a page
states completion. It can process each summary as it arrives. It then requests
details and schema resources only for the commands that it needs. It can
release the snapshot when it finishes.

The selected `view_items` limit bounds the number of summaries in the complete
advertised view. A host returns `view_too_large` before the first page when the
resolved view exceeds this limit. This limit changes disclosure capacity. It
does not authorize any command.

The profile owns the complete capability universe and marks each command as
required or optional. The actor effective set contains all required commands
and the optional commands that the actor activates. An advertised view can
filter disclosure from that set. It cannot add a command, activate a command,
or grant permission. The profile tuple in `session.open` is an assertion and a
compatibility guard. It is not a profile choice. Later command admission still
uses current policy, actor state, limits, and profile rules.

Input and output contracts are full JSON Schema 2020-12 resources. The control
document gives a closed resource manifest. The binding transfers each selected
resource as exact `application/schema+json` bytes. A resource identity is not a
URL or a file path. Clients must not fetch a URI that occurs in discovered
schema content. This design preserves Boolean roots, compound schemas,
references, vocabularies, annotations, and exact numeric text.

Threads, episodes, and turns stay profile data. A thread or episode groups
commands inside one session and uses that session's one history and cursor.
A profile needs a `turn_id` only when it has meaning that differs from
`command_id`. A distinct child actor needs independent discovery, profile
confirmation, and a new session. Parent authority, snapshots, history, and
cursors do not transfer to it.

## Use the artifacts

Pin the schema bytes and their digest in your implementation. A schema URI identifies a contract; it is not permission to fetch an arbitrary URL from a received message.

Pin a source commit with `draft-01` while the draft is under review. See [Changes](../../CHANGELOG.md) for compatibility changes. Published release artifacts must remain fixed.

The schemas cannot validate message history, authorization, saved admission,
or process restart. Capability-discovery artifact checks prove agreement with
the abstract control contract only. They do not prove authentication,
framing, correlation, streaming, close behavior, or binding interoperability.
The [conformance page](../../conformance/README.md) lists these gaps.

## Optional binding artifacts

The [carrier schema](../../specification/draft-01/bindings/encrypted-carrier.schema.json) defines a separate optional binding shape. The [recorded carrier fixtures](../../conformance/fixtures/encrypted-carriers.json) use synthetic ciphertext and signatures. They demonstrate shapes and selected encoding rules, not successful encryption or authentication. These artifacts do not extend the core schema or establish interoperability. Read the [contract and its release requirements](../specification/payload-encryption.md).

The [authority grant schema](../../specification/draft-01/bindings/authority-grant.schema.json) defines closed standing and exact-command grants, plus selection and scalar extension shapes. Apply the [counter authority scope schema](../../specification/draft-01/examples/counter-authority.schema.json) for the concrete counter contract. Both schemas require the [authority byte, trust, scope, and admission rules](../specification/proof-of-authority.md); schema validation alone grants no access.
