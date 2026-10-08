# Language clients

Choose the API that fits your application. Both clients use the same DASP messages and recovery rules.

| Client | Package | Runtime |
| --- | --- | --- |
| [Elixir](elixir/README.md) | `dasp_ex` | Elixir 1.18+, OTP 27+ |
| [TypeScript](typescript/README.md) | `@dasp-protocol/client` | Node.js 22+, ESM |

Both are experimental, version `0.1.0-draft.1`, for `draft-01`. No registry release or production binding is available. The project license is pending.

## What the packages handle

They construct requests, validate core messages, check reply identity, and apply ordered updates to checkpoints. They also route duplex traffic and recover live delivery through fixed-boundary replay, bounded buffering, resync, and reconnect actions. Separate discovery helpers validate progressive capability control documents, pages, selected details, and exact schema resources. They reject malformed JSON and stop on gaps or changed duplicate events.

## What you supply

Supply an authenticated setup adapter, profile validator, state reducer, and durable storage. The Elixir client opens WebSockets with Mint and offers both a functional connection engine and bounded managed streams. The TypeScript client requires an application transport. Neither package implements authenticated setup bytes, a discovery binding mapping, payload encryption, grant verification, or host admission. Save state, cursor, and duplicate evidence together. Keep command IDs and inputs for retries.

A timeout leaves admission unresolved. The packages do not retry automatically or cancel accepted server work.

## Discover capabilities before session open

Capability discovery is an optional setup subprotocol. A binding-specific
probe or offer must authenticate the peers and select one exact discovery
mapping before the first discovery operation. The protocol defines the
control documents and behavior. It does not define these setup-envelope bytes
or transport frames.

The first list reply reveals one actor's exact profile descriptor and a
bounded summary page. The actor has one immutable profile URI and version for
its lifetime. The profile owns the capability universe and marks commands as
required or optional. The actor activates optional commands. A resolved
advertised view can filter disclosure from the actor's effective set, but it
cannot add a capability or grant permission.

The selected `view_items` limit bounds the complete advertised view. A host
returns `view_too_large` before the first page if the resolved view has too many
summaries. This limit does not grant permission.

For a large actor, read summary pages until the terminal page. A client can
process hundreds or thousands of summaries incrementally without keeping the
complete list. It then reads details and full JSON Schema 2020-12 resources
only for selected commands. Schema resources arrive as exact bytes from a
closed manifest. The clients do not fetch resource identities or schema URIs,
and they do not compile discovered schemas by default.

After discovery, the client confirms support for the exact profile. The
profile tuple in `session.open` asserts the discovered actor profile; it does
not choose one. A later command can still fail admission. A profile can group
commands with a thread or episode inside one session. It needs a separate turn
identity only when that identity differs from the command. A child actor needs
its own discovery, profile confirmation, and session. Parent authority,
discovery state, history, and cursors do not transfer.

Use [`DASP.Discovery`](elixir/lib/dasp/discovery.ex) in Elixir. Use the
separate [TypeScript discovery exports](typescript/src/discovery.ts) in
TypeScript. Both entry points keep discovery outside the 14 core message
types. See the [normative discovery
contract](../docs/specification/capability-discovery.md) and the [shared
fixture](../conformance/fixtures/capability-discovery.json).

## Elixir

The [Elixir client](elixir/README.md) uses Jido Signal, Zoi, and Mint WebSocket. Each of its 14 core signal modules owns a static data schema. Requests, replies, and stream elements use `%Jido.Signal{}`. This is a package dependency, not a DASP requirement.

## TypeScript

The [TypeScript client](typescript/README.md) includes type declarations and its schema. Transport calls receive an `AbortSignal`. Browser support is not claimed.

## Build and test

From the repository root:

```sh
npm run clients:test
npm run clients:package
```

The language guides list setup steps and recorded examples. These examples use local reply adapters; they do not start a host.

[Client CI](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml) produces review archives. Tests cover parsing, reply checks, deadlines, retry construction, checkpoint recovery, duplex dispatch, and the shared live-delivery cases. See [protocol capabilities](../docs/specification/capabilities.md) for how clients fit with encryption and authority. See [what is tested](../conformance/README.md) for host and transport gaps.
