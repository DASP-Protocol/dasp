# ADR 0021: Name the agent control contract Seigyo Protocol

Status: Accepted
Date: 2026-09-19

## Context

The protocol controls agent Sessions through commands, receipts, saved
updates, views, traces, and recovery. Its requirement and test IDs used a
prefix from the earlier Keel Client Protocol name. That name no longer
described the system.

`Jido Client Protocol` describes a consumer, but it does not state what the
protocol controls. `Jido Agent Protocol` is broad and produces an unsuitable
initialism. A name tied to Jido Code or WebSocket would also make the protocol
identity depend on one product or transport.

The Japanese term `seigyo` (制御) means technical or system control. The phrase
`jidō seigyo` (自動制御) means automatic control. The term therefore fits a
protocol that forms a command and feedback boundary for agent systems.

## Decision

The canonical name is **Seigyo Protocol**.

Use `Seigyo Protocol` in prose. Use `SEIGYO` when an uppercase identifier is
needed. The name applies to the client-facing control contract, independent of
its transport and implementation. WebSocket is the only current client
transport, but it is not part of the protocol name.

Requirement IDs, test IDs, fixture names, and module names use `SEIGYO-*`.
The migration kept each earlier category and number. For example, the core,
wire, and test categories now have these forms:

```text
SEIGYO-CORE-001
SEIGYO-WIRE-001
SEIGYO-TEST-001
```

The completed migration did not change any wire shape, protocol version,
Signal type, Phoenix topic, application name, or Elixir namespace.

## Consequences

The protocol has a distinct name that can apply outside Jido Code. Jido Code
is one server implementation, and `jido_seigyo` is one client
implementation. Other interfaces can implement the Seigyo Protocol without
adopting Jido Code package names.

The repository uses the canonical Seigyo Protocol name and `SEIGYO-*`
identifiers. Requirement references, fixtures, test modules, file names, and
manifest entries changed together.
