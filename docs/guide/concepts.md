# Core concepts

This page explains the model. The [formal model](../specification/model.md) defines its requirements.

## Actor, host, and session

An **actor** is a logical target that performs application work. A **host authority** manages its sessions, saved command records, and ordered updates. The authority can span more than one machine.

A **DASP server** exposes that host authority to clients. The specification uses *host* for this server role; it does not require a single process or machine.

A **session** binds an actor identity, one profile version, and one saved history. An actor can have several sessions. There is no ordering guarantee between sessions.

A **connection** is temporary. Its failure does not cancel accepted work or erase saved session history.

## Command, receipt, and outcome

A **command** carries application intent with a stable command ID. A **receipt** reports accepted, duplicate, or rejected admission. An **outcome** reports completed, failed, cancelled, or uncertain execution.

Keep these stages separate. An accepted command can still fail. A lost receipt can mean the host accepted the work. Retry the same intent with the same command ID; do not assume it is safe to create a new one.

## Updates, views, and progress

An **update** is an immutable saved fact with a sequence number. A **cursor** records the last update a client applied. Save the cursor with the corresponding application state.

A **view** is a state projection at a coherent cursor. **Progress** is temporary information. It can be lost or repeated and does not advance a saved cursor.

## Three different IDs

| Identity | Meaning |
| --- | --- |
| CloudEvents `source` and `id` | One event |
| `command_id` | One durable intent within a host authority |
| `requestid` | One request attempt and its direct reply |

A new attempt uses a new request ID. An equal command retry keeps its command ID and data. Saved updates keep their original event identity during replay.

## Profiles and bindings

A **profile** defines the application vocabulary and payloads. A **binding** defines how the peers select a contract and exchange messages. Neither can weaken the core admission or recovery rules.

Follow the [worked example](../build/walkthrough.md) to see these concepts together.
