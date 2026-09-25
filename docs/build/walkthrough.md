# The request timed out. Did the work happen?

You ask an agent to make a code change. Then the connection drops. Did the server accept the work? Is it safe to try again?

Follow one task through four common problems. DASP defines what the server saves and what each client can recover.

<WalkthroughStory />

## What this means for your project

Your app should not need to stay connected to know what happened. A DASP server keeps command records, ordered updates, and final outcomes. Clients return to that shared record after a failure.

You still choose the agent, its tools, and what counts as success. DASP does not guarantee exactly-once effects in external services.

<details>
<summary>What must my application define?</summary>

An application profile defines commands, inputs, and results. For this example, success could require passing tests and a confirmed pull request reference.

The profile also defines how to check an external result. In draft-01, an uncertain outcome is final. A later check requires a separate profile action; it cannot change the original outcome.

Cancellation also needs application rules. Stopping new tool calls does not undo a pull request. DASP core has no generic cancellation operation.

</details>

## Take the next step

The dependency task is an illustration. No server runs on this page, and this application profile is not released.

- [Inspect the recorded counter exchange](../reference/recorded-exchange.md) for complete messages and commands to run the artifact checks.
- [Add DASP to your project](README.md) to review the server, client, and profile responsibilities.
