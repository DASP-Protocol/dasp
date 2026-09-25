# A session that survives the connection

DASP defines how a client sends commands to an actor, observes saved outcomes, and recovers after a connection fails. The client and actor can use different languages.

An **actor** performs application work. A **session** gives clients a durable context for that work. A **connection** carries messages while it is available. Closing a connection does not mean that accepted work stops.

## The client loop

1. Open an authorized session.
2. Submit a command with a stable command ID.
3. Keep its receipt. The receipt reports admission, not completion.
4. Apply saved updates in sequence and save the applied cursor.
5. Read the result or a coherent session view.

After connection loss, retry unresolved intent with the same command ID and data. Read saved updates after the last applied cursor. Temporary progress can help the display, but it does not establish a saved outcome.

## What exists today

DASP starts from the Seigyo protocol in Jido Code. The imported source includes a coding profile, an Elixir client, closed schemas, wire fixtures, and portable checks. The current binding uses Phoenix Channel WebSocket frames.

The language-independent general actor contract is being defined. TypeScript is the next client target. There is no released DASP package yet.

::: info Scope
This project contains the protocol, its clients, and shared checks. Actor execution, storage engines, and product interfaces belong to host implementations.
:::

## Where to go next

- Read the [protocol guide](./protocol/index.md) for the source contract.
- Read [recovery](./protocol/recovery.md) for retry and cursor rules.
- Check [client status](./clients/index.md) before choosing an implementation.
- Review the [open decisions](./project/decisions.md) to help define DASP.
