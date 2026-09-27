# Schemas and downloads

Draft-01 uses JSON Schema 2020-12. The core schema defines generic event structure. Application profiles validate their own payloads.

| Artifact | Purpose |
| --- | --- |
| [Core envelope schema](../../specification/draft-01/envelope.schema.json) | The 14 core event types and their data shapes |
| [Counter profile schema](../../specification/draft-01/examples/counter-profile.schema.json) | Illustrative input, state, output, and progress payloads |
| [Example events](../../specification/draft-01/examples/counter.json) | At least one event of each core type |
| [Artifact manifest](../../specification/artifacts.json) | SHA-256 digests for the current schema and example bytes |

## Use the artifacts

Pin the schema bytes and their digest in your implementation. A schema URI identifies a contract; it is not permission to fetch an arbitrary URL from a received message.

Pin a source commit with `draft-01` while the draft is under review. See [Changes](../../CHANGELOG.md) for compatibility changes. Published release artifacts must remain fixed.

The schema cannot validate message history, authorization, saved admission, or process restart. The [conformance page](../../conformance/README.md) lists those gaps.
