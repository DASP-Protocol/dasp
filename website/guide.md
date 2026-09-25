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

## CloudEvents, generic shapes

CloudEvents defines event identity, source, and type. DASP defines sessions, commands, admission, saved outcomes, and replay. Application profiles define the data inside command inputs, outputs, and state.

The core does not require chat, turns, models, or workspaces. A transport binding defines how these events move between a client and a host.

## What exists today

DASP draft-01 includes standalone core requirements, a JSON Schema, example events, and structural checks. It is not a released contract. A production binding, application profile, and DASP clients remain to be implemented.

An imported source implementation supplies reference behavior and an Elixir client for its own contract. It does not establish compatibility with the new draft.

::: info Scope
This project contains the protocol, its clients, and shared checks. Actor execution, storage engines, and product interfaces belong to host implementations.
:::

## Where to go next

- Read the [protocol guide](./protocol/index.md) for the active core draft.
- Read [recovery](./protocol/recovery.md) for retry and cursor rules.
- Check [client status](./clients/index.md) before choosing an implementation.
- Review the [open decisions](./project/decisions.md) to help define DASP.
