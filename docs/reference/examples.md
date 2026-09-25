# Examples and traces

| Artifact | Coverage |
| --- | --- |
| [Counter event set](../../specification/draft-01/examples/counter.json) | Complete examples of all 14 core message types |
| [Counter profile](../specification/example.md) | Inputs, outputs, state, and completion meaning |
| [Invalid event vectors](../../conformance/fixtures/invalid-events.json) | Full events rejected by structural validation |
| [Recovery trace](../../conformance/fixtures/recovery-trace.json) | Lost receipt, equal retry, saved outcome, and two client cursors |
| [Behavioral cases](../../conformance/behavioral-cases.md) | Host and client failure scenarios awaiting a runtime harness |

The event set is a catalog, not a chronological connection transcript. The recovery trace is ordered, but recorded. Run `npm run spec:check` to check both artifacts.

The [walkthrough](../build/walkthrough.md) explains the trace. Application command names such as `counter.add` are profile vocabulary, not core operations.
