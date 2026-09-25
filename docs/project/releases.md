# Release preparation

**Current status: working review draft, core identifier `draft-01`. No tagged DASP specification release is published.**

The intended first review bundle is `0.1.0-draft.1`. This is a proposed publication version. It is different from CloudEvents `specversion: "1.0"`, the event-type suffix `.v1`, and future client package versions.

Project license selection is pending. The preparation command requires an approved `LICENSE` file before it can create a release archive.

## Prepare a review bundle

From a clean checkout:

```sh
npm ci
npm run release:prepare
```

The command runs publication checks and writes a local archive, manifest, checksums, and coverage report under `dist/releases/`. The manifest names the exact source commit. No tag, remote release, registry package, or announcement is created.

The existing schema identifiers keep their published bytes. A future structural change needs a new revision path and explicit compatibility review.

## Contents and evidence

The bundle includes the curated repository source, normative documents, schemas, examples, conformance cases, and the scripts needed to reproduce checks. It also includes a saved test report and checksums. A file manifest establishes artifact identity, not runtime conformance.

Before a formal release, confirm the chosen version and license, review the open decisions, and inspect the bundle. Tag the exact reviewed commit only when release is intended. Keep that tag and its artifacts fixed. See [RELEASING.md](../../RELEASING.md) for the procedure.

## Next implementation milestone

Specify a binding and useful profile, build a persistent example host, and implement Elixir and TypeScript clients. Add concurrent retry, restart, replay, and authorization tests. Publish a compatibility tuple with each implementation: core, profile, binding, and suite version.
