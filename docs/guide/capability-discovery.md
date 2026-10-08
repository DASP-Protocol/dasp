# Discover actor capabilities

A DASP command can represent any operation that an application profile defines.
Before a client opens a session, it can use the optional capability-discovery
setup contract to learn what one actor describes.

Discovery does not add a sixth core operation. It finishes before normal DASP
profile confirmation and `session.open`.

## Setup flow

1. The peers authenticate and select one exact discovery mapping.
2. The client starts a capability list for one actor.
3. The host returns the actor's exact profile and the first summary page.
4. The client reads all summary pages in the same stable snapshot.
5. The client requests details for the commands that it can use.
6. The client reads the required input and output schema resources.
7. The client releases the snapshot when it no longer needs it.
8. The peers confirm the profile, binding, extensions, and limits.
9. The client opens a session and asserts the discovered profile.

The exact setup envelope and transport frames belong to a binding. Draft-01
defines the discovery operations and their behavior, but it does not define a
complete discovery-capable binding.

## Large capability sets

The host does not send one large catalog. The first `capabilities.list` reply
contains one bounded summary page and an opaque continuation token. The client
follows the tokens until a page states that the list is complete.

All pages belong to one immutable snapshot. They use a deterministic order and
the same actor profile. The host cannot silently truncate the list. The client
discards an incomplete list.

The selected `view_items` limit bounds the complete advertised view. If the
view is larger than this limit, the host returns `view_too_large` before the
first page. A later setup can select a larger limit or request a different
advertised view. The limit controls disclosure capacity. It does not grant
permission.

The shared draft fixture checks an actor with 1,000 capabilities across 10
pages. A client can process each page as it arrives. It does not have to keep
all summaries in memory.

## Read only what you need

A summary supplies enough information to choose a command for closer review.
The client uses `capabilities.get` for a bounded set of exact capability
identities. One identity contains the exact profile URI, profile version, and
command name.

A detail document can refer to schema resources. The client reads each resource
by an opaque resource identity from the snapshot. It does not fetch a schema
URI or load a path that occurs in received data.

Input and output contracts are full JSON Schema 2020-12 resources. A closed
manifest identifies all required resources and their exact byte
representations. This supports Boolean schemas, compound schemas, references,
vocabularies, annotations, and exact numeric text.

## Separate the protocol facts

| Fact | What it means |
| --- | --- |
| Capability discovery | The host describes a command for this actor and advertised view. |
| Application profile | The profile defines command meaning, schemas, completion, and domain rules. |
| Advertised view | The host discloses part or all of the actor's effective capability set. |
| Proof of authority | A selected authority contract can permit new work within a defined scope. |
| Admission | The host saved one command intent. |
| Encryption | The selected carrier protects transported content for its permitted reader. |

One fact cannot replace another. An advertised command can still fail current
policy, state, limit, authority, or profile checks. A valid schema does not admit work.

## Scoped disclosure is not scoped authority

The profile defines the complete capability universe and marks each command as
required or optional. One actor activates an effective set from that universe.
An advertised view can filter what an authenticated context sees from the
effective set.

The view cannot add a command, activate an optional command, or authorize a
command. An external security system supplies the maximum disclosure set. The
host checks current disclosure before every page, detail, resource, and release
reply.

## Connection and actor boundaries

A discovery snapshot is temporary connection state. It does not survive a
connection loss. A new connection starts a new enumeration after fresh
authentication and selection.

Each actor has one immutable profile URI and version for its lifetime. A child
actor needs its own discovery, profile confirmation, and session. Parent
authority, discovery state, history, and cursors do not move to the child.

Read the [normative capability-discovery contract](../specification/capability-discovery.md),
inspect the [schemas and fixtures](../reference/schemas.md), or review how a
[profile and binding](../build/profiles-and-bindings.md) support discovery.
