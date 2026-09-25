# ADR 0017: Keep the Seigyo Protocol at the Server edge

Status: Accepted for the local client slice
Date: 2026-09-17

## Context

The first client uses LiveView. Later clients can use another process or host. A client command needs one admission point and one durable result. Model text can arrive before the final Agent state and Session record are ready.

`Jido.Signal.Bus` has its own storage and delivery rules. Jido Code already uses the Session Store to admit commands, keep stable command IDs, and order Updates. Sending client commands through the Bus would add a second command queue and a second record of admission.

## Decision

`jido_seigyo` owns the version 1 client Signals and their Zoi schemas. Each Signal has its own file. The supported command path is:

1. A client sends `SessionOpen` or a `Command` with kind `submit_text` through a Seigyo transport adapter.
2. `Jido.Code.Seigyo.Local` validates the request and maps it to the Server facade. Server admits the command through the Session Store. It returns `SessionOpened` or a `Receipt`. A duplicate command ID returns the original admission position.
   A `submit_text` command can include a model ID. The command record saves the original input for retry checks. Server resolves the effective model ID to ReqLLM options before admission. Before remote access, save that effective ID in the command record, including when the client uses the configured default.
3. A client reads a `View`, ordered `Update` Signals, and a bounded `Trace` through Server. The Store is the source of truth after a reconnect.
4. During an active model request, Server can send bounded `Progress` Signals to local subscribers. Each Signal contains the current reply text, provider supplied reasoning when available, tool call status, command ID, and request event sequence. Progress is temporary. It has no Store cursor and is not replayed. A terminal Update and View replace it. The bounded `Trace` keeps final activity details.

`cancel` and `close` are outside version 1 until Server implements their full lifecycle. A client must not send them as valid Commands.

LiveView and the WebSocket channel are transport adapters for this contract.
Both use `Jido.Code.Seigyo.Local`. They do not call Server operations directly.
LiveView cannot read configuration, server records, model discovery, or auth
state outside the protocol. A later transport must use the same interpreter.
It must not own command state or admission rules. Transport encoding,
authentication, and remote progress delivery need a separate decision and test.

The [Seigyo Protocol](../seigyo/README.md) specifies the detailed current
shapes and required remote proof rules. Its general agent profile, closed
event variants, and coding activity record are proposals that need a later
ADR decision; they are not part of this local decision.

Do not use `Jido.Signal.Bus` for client command ingress or model text. A later Bus use can fan out committed Store Updates if it keeps Store sequence and replay semantics intact.

## Consequences

There is one durable command history. A client can miss Progress and still read the final View and Updates. Live text can vanish when a client disconnects. The Server sends a full bounded snapshot on each Progress Signal, so a client can replace older text without applying missing deltas.
