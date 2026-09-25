# The request timed out. Did the work happen?

You ask an agent to update a dependency, run the tests, and prepare a pull request. Your app shows a spinner. Then the connection drops.

Sending the request was easy. Now you need to know what the server accepted, what the agent did, and whether it is safe to try again.

<WalkthroughStory />

## What needs to survive?

A stream can show activity while a client is connected. Recovery needs a saved record. DASP gives that record meaning at the server boundary.

| Information | What the client can rely on |
| --- | --- |
| Accepted receipt | The server saved admission. Work can still be pending. |
| Progress message | Temporary activity, such as “Running tests.” It does not prove completion. |
| Saved update | A fact with a position in the session history. It can be read again. |
| Saved outcome | The final result the server can establish, including uncertainty. |

A **cursor** is the last saved update a client applied. The client saves that position with its application state. Receiving a receipt or showing a progress message does not advance it.

## Your application still decides

DASP defines the server contract. The agent's tool calls, execution engine, and application policy remain your choice. A profile must make these decisions explicit:

<details>
<summary>When is the work complete?</summary>

For this example, “complete” could require passing tests and a confirmed pull request reference. A message saying “Done” is not enough. The profile defines the evidence needed before the server can save a completed outcome.

</details>

<details>
<summary>What would Cancel mean?</summary>

Stopping new tool calls does not undo a branch or delete a pull request. A cancellation command needs a profile-defined target and cleanup boundary. DASP core does not supply a generic cancellation operation.

</details>

<details>
<summary>How do you check an external effect?</summary>

Use the external service's effect keys, a transaction where available, or a way to look up the result. If the server cannot establish the effect, it saves an uncertain outcome. DASP does not guarantee exactly-once external effects.

An uncertain outcome stays fixed in draft-01. Later reconciliation requires a separately specified profile action; it cannot rewrite the original outcome.

</details>

## Inspect a complete recorded exchange

The story uses an illustrative dependency-update command. To inspect checked-in messages, continue with the smaller [counter exchange](../reference/recorded-exchange.md). It includes the install commands, full CloudEvents, a lost receipt, a retry, and two clients recovering the same state.

[Inspect the recorded exchange](../reference/recorded-exchange.md) · [Read the recovery requirements](../specification/recovery.md)
