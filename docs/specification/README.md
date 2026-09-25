# DASP specification guide

The source contract is the [Seigyo specification](../../upstream/seigyo/docs/seigyo/README.md). This guide introduces it without adding wire requirements.

## Common contract

A Session is a durable client context with ordered saved history. A Command states client intent and has a stable retry identifier. A Receipt reports admission. A saved outcome reports completion, failure, cancellation, or uncertainty. Temporary Progress does not prove completion.

An Update is a saved fact. Its positive integer sequence is contiguous within its Session. A client saves the last sequence that it has applied. After connection loss, it reads saved Updates after that cursor. A View presents a bounded, coherent saved state.

The trusted connection identity controls access. Signal fields, identifiers, and transport topics do not grant access. A connection loss does not cancel accepted work.

These meanings can apply across languages. The specification must not require an Elixir process, struct, or exception in a client. The imported JSON schemas, frame fixtures, limits, and portable validation rules provide the external data contract.

## Current profile and future scope

The current production profile is `coding` version `1`. It includes Workspace, model, configuration, turn, attachment, and result types. General actor profiles must preserve the common identity, admission, retry, replay, and outcome rules. They need their own closed schemas and conformance cases before use.

The current opt-in initialization includes a test-only `echo` profile. It is evidence for profile separation, not a released general-actor profile. Public Work, schedules, and collaboration remain proposals or draft contracts where marked by the source.

## Source map

| Subject | Source |
| --- | --- |
| Meaning and ownership | [Model](../../upstream/seigyo/docs/seigyo/model.md) |
| Operations and correlation | [Messages](../../upstream/seigyo/docs/seigyo/messages.md) |
| Admission and outcome | [Processing](../../upstream/seigyo/docs/seigyo/processing.md) |
| Retry and saved Updates | [Delivery](../../upstream/seigyo/docs/seigyo/delivery.md) |
| Cursor application | [Replay](../../upstream/seigyo/docs/seigyo/replay.md) |
| Current wire types | [Signal catalog](../../upstream/seigyo/docs/seigyo/signals.md) |
| Transport and validation | [Wire](../../upstream/seigyo/docs/seigyo/wire.md) |
| Version and feature selection | [Initialization](../../upstream/seigyo/docs/seigyo/initialization.md) |
| Immutable baseline | [Release policy](../../upstream/seigyo/docs/seigyo/release-policy.md) |

The name DASP is the project name. Keep `jido.client.v1.*`, `seigyo.core/1`, and `SEIGYO-*` unchanged in imported contracts until a separate version and migration decision permits a change.
