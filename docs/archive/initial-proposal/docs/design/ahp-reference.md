> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Microsoft AHP reference

The local reference is [Microsoft Agent Host Protocol](https://github.com/microsoft/agent-host-protocol), cloned to `reference/agent-host-protocol/`.

Reviewed commit: `296b25e7b698a4a84a0ee5a28d9573e70048a0bf`.

The reviewed AHP documents define JSON-RPC messages, version selection, channel subscriptions, snapshots, and reconnect behavior. Its protocol types are defined in TypeScript and used to generate JSON Schema. Its clients have separate package release versions.

Sources at the reviewed commit:

- [Overview](https://github.com/microsoft/agent-host-protocol/blob/296b25e7b698a4a84a0ee5a28d9573e70048a0bf/docs/specification/overview.md)
- [Subscriptions](https://github.com/microsoft/agent-host-protocol/blob/296b25e7b698a4a84a0ee5a28d9573e70048a0bf/docs/specification/subscriptions.md)
- [Lifecycle](https://github.com/microsoft/agent-host-protocol/blob/296b25e7b698a4a84a0ee5a28d9573e70048a0bf/docs/specification/lifecycle.md)
- [Versioning](https://github.com/microsoft/agent-host-protocol/blob/296b25e7b698a4a84a0ee5a28d9573e70048a0bf/docs/specification/versioning.md)

## DASP choices

DASP is a separate protocol for general durable actors. It does not claim AHP wire compatibility. An adapter would need an explicit mapping and separate tests.

The DASP draft uses JSON-RPC, exact version selection, snapshot subscriptions, and separate client releases. It adds a defined durable commit boundary and stable command retry identities. Its specification is independent of any client language. The first draft sends complete snapshots to avoid requiring application reducers in every client.

The Microsoft clone retains its original license and notices. It is excluded from DASP source control. No upstream code has been copied into DASP. Record a new reviewed commit when updating the reference; upstream changes do not automatically change DASP.
