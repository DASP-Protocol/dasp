# What is tested

A schema pass proves that a message has a valid shape. A recovery test must also prove what happens when a process or connection fails.

DASP currently has artifact checks and separate client package tests. There is no complete host conformance runner or certification claim.

## Available evidence

| Check | Runs today | Does not establish |
| --- | --- | --- |
| Core artifacts | All 14 event types, invalid vectors, profile payloads, and recorded recovery | Behavior of a running host |
| Capability discovery artifacts | Closed control examples, exact schema bytes, shared 1,000-summary scale and limit fixtures, recorded identity cases, and profile-boundary fixtures | Discovery-capable binding selection, authentication, framing, correlation, live host behavior, streamed transport, or binding interoperability |
| WebSocket delivery transcripts | Recorded capture/confirmation order, retained and conflicting opens, fixed replay pages, late cancelled pages/failures, and open timeout | Running subscriptions, real commit races, queue bounds, liveness, or permissions |
| Encrypted carrier artifacts | Carrier/header shapes, raw header integer tokens, Unicode restrictions, duplicate header keys, canonical base64url, selected byte bounds, and matching metadata | Outer wire parsing, cryptography, key confirmation, setup, peer trust, or runtime encrypted delivery |
| Authority artifacts | Closed grant/selection schemas, original-byte parsing, Ed25519 vectors with one Node implementation, scope examples, recorded retries/budgets, and serial commit orders | Independent cryptographic agreement, current trust administration, actual concurrency, crash safety, or encrypted exchanges |
| Extension contract | Written selection, scope, saved protection, and version runtime cases | Actual setup confirmation, dependency enforcement, session protection, or upgrade behavior |
| Elixir and TypeScript clients | JSON parsing, core validation, reply checks, deadlines, retries, checkpoints, duplex dispatch, completion pushes before a receipt, and shared live-recovery cases | Persistent storage, a WebSocket connection adapter, encryption, authority enforcement, or a complete live binding |
| Host and binding behavior | Written runtime cases only | Admission atomicity, concurrent retries, restart, stale-worker control, authorization, or power-loss safety |

The artifact report and requirement index below cover recorded fixtures. Client package tests run separately and do not count as host evidence.

## Run and inspect

Use [Running checks](running-checks.md) for commands and output. The [shared capability-discovery fixture](fixtures/capability-discovery.json) records deterministic scale and failure inputs for both clients. The [behavioral cases](behavioral-cases.md) specify future fault tests. The [machine-readable requirement index](requirements.json) is the source for the table below.

<!-- REQUIREMENT_COVERAGE -->

## Claim boundaries

A future result must identify the core, profile, binding, discovery and selected extension identities and versions, content pins, settings, dependencies, suite, implementation version, test environment, executed and skipped cases, failures, connection boundary, and durability boundary. Capability-discovery artifact checks are abstract contract evidence only. They do not establish discovery binding interoperability. Optional CloudEvents attribute parsing is not evidence of required extension enforcement. Do not infer power-loss safety from process-restart tests. No general certification badge is issued by this draft suite.

The [report template](report-template.json) describes the evidence to record for an implementation. Its empty result lists are not passing results.
