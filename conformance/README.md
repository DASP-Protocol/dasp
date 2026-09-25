# Draft conformance suite

**Scope: artifact validation. No host or client conformance is established.**

The suite validates recorded draft-01 events, schemas, a counter profile, and a recovery trace. It checks structure and selected cross-message relationships. It does not connect to a host or execute actor work.

## Coverage levels

| Scope | Current evidence |
| --- | --- |
| Core event shapes | All 14 types represented; positive and negative fixtures |
| Example relationships | Replay identity, admission sequence, settlement, and cursors |
| Recorded recovery | Lost receipt, equal retry, conflict, and two clients reaching the same state |
| Raw message parsing | Not executed: duplicate JSON keys, invalid UTF-8, full Unicode rules, byte/depth limits |
| Host behavior | Not executed: admission atomicity, concurrent retries, restart, stale workers, authorization |
| Client behavior | Not executed: actual persistence, reconnect, unknown events, duplicate handling |
| Binding and profile runtime | Not executed: no released binding or production profile |

Separate [client package tests](../clients/README.md#build-and-test) now execute raw JSON parsing, core validation, reply correlation, request deadlines, equal retry construction, replay bounds, and checkpoint duplicate handling in Elixir and TypeScript. They use in-process transport adapters and the shared recorded vectors. They are not included in the artifact report or the host requirement coverage index below. Actual storage, reconnect, host restart, and live binding tests remain open.

A schema pass alone does not establish protocol conformance. “Artifact-partial” in the index means that a recorded example touches part of a requirement; it does not prove the behavior of an implementation.

## Run and inspect

Use [Running checks](running-checks.md) for commands and output. The [behavioral cases](behavioral-cases.md) specify future fault tests. The [machine-readable requirement index](requirements.json) is the source for the table below.

<!-- REQUIREMENT_COVERAGE -->

## Claim boundaries

A future result must identify the core, profile, binding, suite, implementation version, test environment, executed and skipped cases, failures, and durability boundary. Do not infer power-loss safety from process-restart tests. No general certification badge is issued by this draft suite.

The [report template](report-template.json) describes the evidence to record for an implementation. Its empty result lists are not passing results.
