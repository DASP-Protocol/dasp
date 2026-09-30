# Message examples and traces

Select a message to inspect its complete CloudEvents JSON. These examples cover all 14 core types in draft-01.

<MessageExamples />

## Download the evidence

| Artifact | Contents |
| --- | --- |
| [Counter event set](../../specification/draft-01/examples/counter.json) | Full examples of every core type |
| [Counter profile](../specification/example.md) | Commands, state, outputs, and completion rules |
| [Recovery trace](../../conformance/fixtures/recovery-trace.json) | Lost receipt, equal retry, conflict, and two client cursors |
| [WebSocket delivery transcripts](../../conformance/fixtures/websocket-delivery-traces.json) | Normal live delivery, fixed-boundary reconnect, and resync with a late cancelled-read reply |
| [Invalid events](../../conformance/fixtures/invalid-events.json) | Messages rejected by validation |
| [Proposed encrypted carrier](../../conformance/fixtures/encrypted-carriers.json) | Synthetic carrier shapes; no valid cryptography |
| [Proposed encrypted raw headers](../../conformance/fixtures/encrypted-header-vectors.json) | Exact integer tokens, Unicode, and duplicate header keys; no setup or cryptography |

The event set is a catalog. The recovery trace is ordered. Both are recorded artifacts, not a live host.

[Follow the trace](../build/walkthrough.md) or [run the checks](../../conformance/running-checks.md).
