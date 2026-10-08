# Connection management cases

Status: private-fork draft-01. This file is excluded from the public site and public conformance index.

The [connection contract](../../docs/specification/connection-management.md) has six requirement groups. The TypeScript and Elixir tests execute local dispatcher and output queue behavior. Elixir public API tests also execute local TCP and TLS WebSocket servers, bounded streams, fixed drain deadlines, and physical close under a blocked validator. No durable host, released authenticated DASP setup handshake, encryption engine, or QUIC transport is executed.

## Client and queue evidence

Source files:

- `clients/typescript/test/management.test.mjs`
- `clients/elixir/test/management_test.exs`
- `clients/elixir/test/public_api_test.exs`

Run `npm run clients:test` from the repository root. The tests cover:

| Behavior | Evidence scope |
| --- | --- |
| Drain rejects new requests, retains a pending receipt, and joins the original deadline | Both dispatchers |
| A lost receipt retains the original command identity and input on an explicit retry through a fresh dispatcher | Both clients; mock transport, no durable host |
| A final callback completes before the normal closed notice | Both dispatchers |
| A blocked session dispatcher leaves a separate session dispatcher usable | Both dispatchers; separate mock drivers |
| Driver readiness rejects traffic before handoff or receive processing; loss of established setup and wrong received session close their dispatcher | Both dispatchers; driver state, no authentication handshake |
| Invalid drain deadlines leave the dispatcher open | Both dispatchers |
| Session rotation preserves order and charges an active write | Both output queues |
| Message and byte reserves protect control capacity; finite control preference permits ordinary output | Both output queues |
| One session reaches its own message and byte bounds before it can use the full connection bound | Both output queues |
| Only adjacent matching progress is replaced | Both output queues |
| Resync discards queued attachment output while it retains direct replies and input records | Both output queues; no host storage execution |
| Invalid limits, wrong lease completion, and closed queue reuse fail | Both output queues |

These checks support local implementation claims for DASP-CONN-002 through DASP-CONN-005. They do not establish complete conformance to those groups. They do not prove crash durability, host permission release checks, or complete binding interoperability. Elixir socket tests provide local evidence for bounded physical shutdown under a blocked validator.

## RUN-CONN-RECOVERY

Status: specified, not executed. Requirement groups: DASP-CONN-001, DASP-CONN-004, DASP-CONN-006.

Admit a command and lose its receipt. Drain or fail the connection. Route fresh authenticated recovery to another host worker. Retry the original command ID and input with a new request ID. Verify one admission and the original saved decision. Apply saved history once from the last saved cursor. Restart the host within its declared durability contract and repeat. Verify that connection replacement does not reset shared accounting when an extension is selected.

## RUN-CONN-ISOLATION

Status: specified, not executed. Requirement groups: DASP-CONN-002, DASP-CONN-003.

Use separate WebSocket connections for two sessions. Block one writer, expire its open request, and revoke its read permission in separate runs. Verify that the affected connection closes and the other session continues. Repeat with two sessions on one connection. Verify that a required connection close ends both attachments. Do not report independent network streams for that shared connection.

## RUN-CONN-OUTPUT

Status: specified, not executed. Requirement group: DASP-CONN-003.

Connect a busy session and an ordinary session to a shared writer. Exercise session and connection count and byte bounds, including active writes and carrier buffers. Verify finite control preference, session rotation, and per-session order. Queue an open confirmation, saved pushes, direct replies, and a resync transition. Verify their required order. Drop temporary progress only. Force a capacity failure, stop the affected attachment, and release resync after any permitted active write. Verify that no old attachment update follows resync and that all saved records remain available.

## RUN-CONN-DRAIN

Status: specified, not executed. Requirement group: DASP-CONN-004.

Begin drain with a pending command, pending read, active write, and ordered checkpoint callback. Refuse new local requests. Repeat the drain request with a longer deadline and verify the original deadline. Finish a successful exchange, then force deadline loss in a separate run. Verify bounded physical close through the independent driver deadline. Verify that admitted work and saved history survive close. Check that the client retains unresolved command intent and does not infer rejection or terminal success. Repeat during host shutdown.

## RUN-CONN-SETUP

Status: specified, not executed. Requirement groups: DASP-CONN-001, DASP-CONN-005.

Offer TLS or QUIC early data with each core request type. Verify no core handoff, admission, or read disclosure before full fresh authentication and mutual selection. Replace a protected session's connection with a weaker offer and verify refusal. Invalidate setup while a local send callback waits; verify no later handoff. Revoke permission while protected output waits; verify the binding's protected close behavior. A local readiness callback alone is insufficient evidence for this case.

## RUN-CONN-BINDING

Status: specified, not executed. Requirement groups: DASP-CONN-002, DASP-CONN-006.

This case applies only when a later stream binding exists. Verify the selected stream-to-session mapping, per-session order, late reply handling, stream failure, and connection failure. If path migration is supported, change the network path while the authenticated connection remains valid. Verify unchanged session identity, command identity, applied cursor, grant expiry, and shared accounting. Then lose the connection and verify fresh setup and core recovery. The current WebSocket draft and local queue do not pass this case by implication.
