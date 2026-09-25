# Source mapping: Seigyo to DASP

This is a non-normative design record. DASP is defined by its own core specification, not by imported type names or implementation modules. The source files under `upstream/seigyo/` remain unchanged.

## Signals that inform the core

| Source signal or behavior | Generic DASP form | Decision |
| --- | --- | --- |
| SessionOpen / SessionOpened | Session open / opened | Actor identity and profile replace coding workspace fields |
| Command, TurnSubmit | Command with name and input | No core text, turn, model, or attachment fields |
| Receipt, TurnReceipt | Admission receipt | Preserve saved admission versus completion |
| Update | Saved update | Generic admission, outcome, and application variants |
| Result | Outcome | Profile defines output and completion scope |
| View | View at a cursor | Profile defines projected state |
| UpdatesPage | Updates page | Contains original CloudEvents, not only update data |
| Progress | Progress | Temporary, never a saved cursor |
| ResyncRequired | Resync required | Replay starts from the client's applied cursor |
| Failure | Protocol failure | Keep failure separate from rejected admission and execution |
| Typed read arguments | Read-request CloudEvents | Uniform shapes independent of transport calls |
| Session configuration, fork, attachments, workspace operations | Future profiles or extensions | Not promoted into the core |
| Turn steering / cancellation | Explicit profile commands | No implicit chat lifecycle |
| HistoryPage / Trace | Optional profile or diagnostics | Not required for core recovery |
| Proposed collaboration / public Work / schedules | Future profiles or extensions | No current implementation claim |

Sources: [signals](../../upstream/seigyo/docs/seigyo/signals.md), [messages](../../upstream/seigyo/docs/seigyo/messages.md), [processing](../../upstream/seigyo/docs/seigyo/processing.md), and [replay](../../upstream/seigyo/docs/seigyo/replay.md).

## Deliberate differences

- DASP defines its own event namespace. It does not rename imported schemas in place.
- Source UUID7 and prefixed IDs become generic opaque IDs.
- Source logical role paths become producer-selected absolute source URIs.
- DASP accepts valid optional CloudEvents context and extension attributes; it does not impose the source's five-attribute remote projection.
- Saved DASP updates retain their original CloudEvents identity on replay. The source store can regenerate an envelope ID. An adapter needs a persistent, stable mapping; forwarding a freshly generated ID is not sufficient.
- Source mutation families and typed operations are not automatically core commands. Each supported behavior needs a defined application profile.
- Source runtime, persistence, and workspace assumptions become declared host and profile requirements.
- DASP draft-01 does not adopt Phoenix Channel frames as its required binding.
- DASP's encoded-byte limits replace the source portable-map value-cost formula.
- The draft pins the session profile for its lifetime. It does not silently import source configuration migration behavior.

## Adapter requirements

An adapter must map identity scope, command equality, saved sequences, outcomes, profile schemas, and transport errors. It must preserve the distinction between a receipt and a terminal result. It must not treat `submit` and `submit_turn` as aliases: the source has different admission and input behavior.

No such adapter is implemented here. The imported Elixir client and coding-v1 fixtures prove source behavior only. They do not prove DASP draft-01 compatibility.
