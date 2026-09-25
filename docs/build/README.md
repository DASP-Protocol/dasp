# Add DASP to your project

**Current stage: contract review.** You can run the artifact checks and map an application onto the draft. Experimental Elixir and TypeScript client packages are available for local use. A production transport binding is not released.

## Build a client

1. Identify the actor host and its supported core, profile, and binding versions.
2. Select that exact combination before submitting application commands.
3. Open an authorized session with its actor identity and profile.
4. Save a command ID and complete input before the first submission. Keep them for retries.
5. Treat a receipt as admission. Read the saved outcome for completion.
6. Apply saved updates in order. Save the applied cursor with application state.
7. After connection loss, recover unresolved commands and read after the saved cursor.

Authentication and endpoints come from the binding. Do not use a CloudEvents `source` URI as a destination or access grant.

## Expose an actor through a host

1. Define the application's commands and state in a profile.
2. Validate and authorize requests before admission.
3. Save command identity, retry data, and the admission update as one recoverable decision.
4. Dispatch only admitted work. Use application effect keys or reconciliation where external effects require them.
5. Commit ordered updates and one immutable terminal outcome.
6. Serve coherent views, outcomes, and replay pages to authorized clients.
7. Recover after process restart and document the tested durability boundary.

Storage and execution remain your choice. The [recovery requirements](../specification/recovery.md) define observable behavior.

## Define a profile

Specify input and output schemas, completion rules, state projection, command ordering, cancellation, progress, and errors. Supply valid and invalid examples plus behavioral cases. Keep domain data inside the designated profile payload fields.

Use the [counter profile](../specification/example.md) as a small example. For an agent, define an application command such as `report.create` and state exactly when its result becomes complete. This vocabulary is illustrative.

## Try the current artifacts

Start with the [illustrated walkthrough](walkthrough.md) to see why command identity, saved outcomes, and recovery matter. Then inspect the [recorded counter exchange](../reference/recorded-exchange.md) for install commands and artifact checks. Those checks compare recorded messages and expected relationships; they do not start a host or run an actor.

See [client status](../../clients/README.md) and [open decisions](../project/feedback.md) before planning an implementation. The next implementation milestone is one specified binding and a persistent example host tested with both client packages.
