# TypeScript client

Status: not implemented.

Target the [DASP CloudEvents core](../../docs/specification/README.md), not the imported transport frames. Keep the core decoder, profile validation, transport binding, and application state separate.

Preserve safe integers, stable command IDs, saved CloudEvents identities, and applied update cursors. A receipt must not resolve an API that promises a completed outcome. Temporary progress must not advance a saved cursor.

Start with the [draft schema](../../specification/draft-01/envelope.schema.json) and [example events](../../specification/draft-01/examples/counter.json). The first transport binding, profile, package API, and runtime fault checks remain to be implemented. UI code stays outside the client.
