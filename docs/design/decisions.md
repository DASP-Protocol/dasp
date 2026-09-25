# DASP design decisions

DASP now defines a standalone generic actor-session contract based on CloudEvents. Source signals inform the semantics; they do not set the public wire names or require a coding product.

## Selected for draft-01

| Area | Decision |
| --- | --- |
| Envelope | CloudEvents 1.0, structured JSON |
| Core | Generic sessions, commands, receipts, updates, outcomes, views, and progress |
| Domain data | Explicit versioned application profiles |
| Identity | Opaque IDs; command keys span sessions in one host authority |
| Replay | Contiguous saved sequences and stable CloudEvents identities |
| Completion | Immutable saved outcome, including uncertainty |
| Data | Closed core shapes and profile-defined nested objects |
| Transport | Separate binding; none selected for release |
| Language | Same wire values and behavior for Elixir and TypeScript |
| Source | Immutable reference import, with a separate migration map |

## Remaining release work

1. Review the core draft and negative cases.
2. Select and specify the first transport binding, including discovery and authentication.
3. Publish the first useful application profile and its behavioral checks.
4. Implement an independent DASP host or a reviewed source adapter.
5. Implement Elixir and TypeScript clients against the same core, profile, and binding.
6. Add fault-injection tests for concurrency, lost replies, replay, restart, and uncertain effects.
7. Freeze a release bundle with schema and fixture digests.

The draft includes structural schemas and examples. It does not claim a complete transport or server implementation. See the [source mapping](seigyo-mapping.md) for preserved rules and deliberate compatibility changes.
