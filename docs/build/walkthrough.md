# Follow a command through DASP

This counter starts at 0. The client asks it to add 3, loses the receipt, and retries. The value remains 3.

Use **Next** to follow each message, or **Play** to run the trace. Select a stage to inspect retries, recovery, or a command conflict.

<CommandTrace />

This is a recorded example, not a running host. `counter.add` belongs to the example profile. The saved history and message JSON come from the checked-in recovery trace.

## Read the identifiers

| Field | Meaning |
| --- | --- |
| `session_id` | The shared actor session |
| `command_id` | One command; keep it and its input for retries |
| `requestid` | One request attempt and its reply |
| `source` + `id` | One event; replay preserves both |
| `sequence` | A saved update's position in the session |

A client saves its last applied sequence, called its **cursor**, with its application state. A receipt, progress message, or received page does not advance that cursor by itself.

## Check the example locally

Use Node.js 22 or later:

```sh
git clone https://github.com/DASP-Protocol/dasp.git
cd dasp
npm ci
npm run spec:check
```

The checker validates messages and recorded recovery checkpoints. It writes `dist/conformance-report.json`. It does not execute an actor or test a live disconnect.

Inspect [the trace file](../../conformance/fixtures/recovery-trace.json) and [counter profile](../specification/example.md).

## Connect your implementation

Your **profile** defines commands, data, and what completion means. Your **host** saves admission and outcomes, executes work, and serves recovery reads. Your **binding** defines transport, authentication, and message routing.

A disconnect does not cancel accepted work. If the host cannot establish execution effects during recovery, it records `uncertain` and prevents unsafe repeat execution. DASP does not guarantee exactly-once external effects.

Start with [the client packages](../../clients/README.md) or [host implementation steps](host.md). Use the [message catalog](../specification/messages.md) for all operations, including state views, progress, and errors.
