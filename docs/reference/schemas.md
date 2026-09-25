# Schemas and downloads

Draft-01 uses JSON Schema 2020-12. The core schema defines generic event structure. Application profiles validate their own payloads.

| Artifact | Purpose |
| --- | --- |
| [Core envelope schema](../../specification/draft-01/envelope.schema.json) | The 14 core event types and their data shapes |
| [Counter profile schema](../../specification/draft-01/examples/counter-profile.schema.json) | Illustrative input, state, output, and progress payloads |
| [Example events](../../specification/draft-01/examples/counter.json) | At least one event of each core type |
| [Artifact manifest](../../specification/artifacts.json) | SHA-256 digests for published schema and example bytes |

## Use the artifacts

Pin the schema bytes and their digest in your implementation. A schema URI identifies a contract; it is not permission to fetch an arbitrary URL from a received message.

The previously published draft-01 schema bytes remain fixed. Behavioral and editorial work is identified by the source commit until a formal release is tagged. A structural change needs a new schema revision path.

The schema cannot validate message history, authorization, saved admission, or process restart. The [conformance page](../../conformance/README.md) lists those gaps.

## Release preparation

A maintainer can run `npm run release:prepare` from a clean checkout to create a local review bundle with a manifest, checksums, and coverage report. It does not create a Git tag or GitHub release. See [release preparation](../project/releases.md).
