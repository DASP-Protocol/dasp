# ADR 0009: Use Phoenix for client transport

Status: Amended by ADR 0019; coding v1 uses WebSocket only
Date: 2026-09-17

## Context

The running harness needs JSON request and response calls and live Session
updates. A client can disconnect while its accepted command continues. The
native Server and Session Store already own command and replay rules.

## Decision

The web app owns Phoenix client transport adapters. Coding v1 uses one Phoenix
Channel WebSocket for calls, bounded reads, live Session Updates, and temporary
Progress. The adapter validates versioned Seigyo Signals and calls the local
Seigyo interpreter. ADR 0019 fixes its frames. HTTP remains possible future
work and is not part of coding v1.

The Channel does not own command state. A reconnecting client reads committed
Updates after its last sequence. If that cursor cannot be used, it reads a
fresh View and resumes from the View cursor. Progress can be lost; a final
Update and View replace it. Keep Phoenix dependencies out of the native Server.

For connected-client presence, the web app may use Phoenix Presence on an
authorized Session topic. Track only small, temporary metadata. Presence
joins and leaves are not Session Updates and do not supply replay or access
rights. Saved User identity, Session grants, and Command attribution belong
to the canonical data store. Check access before tracking a connection and
again before sending Session data. A reconnecting client gets a fresh
presence snapshot.

Define and test wire encoding, client identity, and authorization before a
remote client can connect. Keep the current web endpoint bound to loopback
until that work is complete.

## Consequences

The Channel serves bounded reads, commands, and live delivery. LiveView and
the Channel use the same local Seigyo interpreter. The Jido Code Store remains
the source for ordered replay after a disconnect.

## Proof gate

Use two client processes over a real transport. Prove submit, detach,
reattach, cursor replay, gap handling, and bounded Views. Use a scripted mock
model for the same client contract checks as the native Server path. The
[Seigyo Protocol](../seigyo/README.md) is the one detailed source for wire
shapes, cursor rules, and conformance cases.
