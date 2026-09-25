# ADR 0004: Use one versioned client contract

Status: Accepted
Date: 2026-09-17

## Context

TermUI, GPUI, Hologram, and automation need the same session meaning. A common Elixir function alone does not prove that a separate client process can reconnect.

## Decision

jido_seigyo owns portable command, receipt, view, update, error, and protocol-version values. All clients use these meanings. A server transport will encode them for clients outside the server process. Start with attach, snapshot, submit, ordered update, detach, and reattach. Give commands stable IDs. Give updates a session sequence or revision and a gap response.

Do not put PIDs, references, functions, renderer trees, terminal cells, DOM values, or native window data in the portable contract.

## Consequences

Each client owns local draft text, focus, layout, and navigation. The server owns shared session facts. A transport may vary, but it must not create another command path or another session state machine.

Choose the first transport and wire encoding in a later record after a small cross-process test. Keep request-response API calls distinct from a live update stream.

The [Seigyo Protocol](../seigyo/README.md) specifies operations, Signal
shapes, and replay rules. It marks proposals separately from this decision.
