# What is tested

A schema pass proves that a message has a valid shape. A recovery test must also prove what happens when a process or connection fails.

DASP currently has artifact checks and separate client package tests. There is no complete host conformance runner or certification claim.

## Available evidence

| Check | Runs today | Does not establish |
| --- | --- | --- |
| Core artifacts | All 14 event types, invalid vectors, profile payloads, and recorded recovery | Behavior of a running host |
| WebSocket delivery transcripts | Recorded capture/confirmation order, retained and conflicting opens, fixed replay pages, late cancelled pages/failures, and open timeout | Running subscriptions, real commit races, queue bounds, liveness, or permissions |
| Proposed encrypted carrier artifacts | Carrier/header shapes, raw header integer tokens, Unicode restrictions, duplicate header keys, canonical base64url, selected byte bounds, and matching metadata | Outer wire parsing, cryptography, key confirmation, setup, peer trust, or runtime encrypted delivery |
| Proposed authority artifacts | Closed grant/selection schemas, original-byte parsing, Ed25519 vectors with one Node implementation, scope examples, recorded retries/budgets, and serial commit orders | Independent cryptographic agreement, current trust administration, actual concurrency, crash safety, or encrypted exchanges |
| Elixir and TypeScript clients | JSON parsing, core validation, reply checks, deadlines, retries, replay bounds, and checkpoints | Persistent storage or a live binding |
| Host and binding behavior | Written runtime cases only | Admission atomicity, concurrent retries, restart, stale-worker control, authorization, or power-loss safety |

The artifact report and requirement index below cover recorded fixtures. Client package tests run separately and do not count as host evidence.

## Run and inspect

Use [Running checks](running-checks.md) for commands and output. The [behavioral cases](behavioral-cases.md) specify future fault tests. The [machine-readable requirement index](requirements.json) is the source for the table below.

<!-- REQUIREMENT_COVERAGE -->

## Claim boundaries

A future result must identify the core, profile, binding, suite, implementation version, test environment, executed and skipped cases, failures, and durability boundary. Do not infer power-loss safety from process-restart tests. No general certification badge is issued by this draft suite.

The [report template](report-template.json) describes the evidence to record for an implementation. Its empty result lists are not passing results.
