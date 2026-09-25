# A command and its recovery

This walkthrough validates recorded examples. It does not run a server or inject a live connection failure.

## Run the checks

Use Node.js 22 or later:

```sh
git clone https://github.com/DASP-Protocol/dasp.git
cd dasp
npm ci
npm run spec:check
```

The command reports schema cases, fixture relationships, and the recorded recovery trace. It writes `dist/conformance-report.json` with the executed case IDs. The exact counts come from the checked-in fixtures.

## Follow one command

The [counter profile](../specification/example.md) starts at zero. A client opens `session-counter` on `counter-main` with profile `urn:example:dasp:counter`, version `1`.

It submits `counter.add` with `command_id: command-add-1` and input `{ "amount": 3 }`.

| Step | Evidence | Meaning |
| --- | --- | --- |
| Open | `dasp.session.opened.v1`, cursor 0 | The session identity is saved |
| Admit | `command.accepted`, sequence 1 | The command is admitted |
| Receipt lost | Accepted receipt is not delivered | The client cannot infer rejection |
| Save state | `counter.changed`, sequence 2, value 3 | Application state changed |
| Settle | `command.outcome`, sequence 3 | Completed outcome is saved |
| Retry | Same command ID and data, new request ID | The host reports duplicate admission at sequence 1 |
| Read outcome | Settled result at sequence 3 | Value remains 3 |
| Second client | Reads after cursor 0 | Reads the same three saved updates |

The [recorded recovery trace](../../conformance/fixtures/recovery-trace.json) contains complete events and expected client checkpoints. The checker compares these records. It does not prove that a host makes these decisions correctly.

## Recover the first client

The first client has saved state at cursor 1. It reads updates after 1, applies sequences 2 and 3, and saves state `{ "value": 3 }` with cursor 3. The second client starts from cursor 0 and reaches the same state.

The nested replay events keep their original `source` and `id`. A page has a separate event ID and request ID. Those IDs are not application cursors.

## Check failure cases

Changing the input to `{ "amount": 4 }` under `command-add-1` is a conflict after admission. It cannot mean new work. An unknown command read is a failure, not a pending outcome.

The [negative fixtures](../../conformance/fixtures/invalid-events.json) include malformed envelopes and inconsistent receipt or outcome shapes. Runtime conflicts, concurrent retries, and restart behavior have separate [behavioral case definitions](../../conformance/behavioral-cases.md).

Continue with the [formal message catalog](../specification/messages.md) or [conformance coverage](../../conformance/README.md).
