# Connection management

Status: public non-normative design note. This document is not part of the
draft-01 contract. It is excluded from the generated site and public
conformance index until its final placement is selected.

This document adds connection rules to the [WebSocket delivery draft](websocket-live-delivery.md). These rules belong to a binding. They add no core message, CloudEvents attribute, or extension. The core retains five requests and fourteen message types. A binding that claims these rules MUST identify and pin this draft in its exact selected contract. This document does not define setup bytes or complete the first binding.

The TypeScript and Elixir clients implement local drain, optional session scope checks, and optional driver readiness checks. Both packages also supply a bounded host output queue. The Elixir package also supplies a Mint WebSocket driver, a functional owning-process API, and a managed client with bounded subscriptions. The repository has no running durable host, authenticated setup wire implementation, or QUIC binding. Client and queue tests do not establish complete binding conformance.

## State and lifetime {#dasp-conn-001}

Requirement group **DASP-CONN-001**.

The host MUST keep session and command semantics independent of the connection that carries a request. Each core request MUST retain its existing explicit session identity and context. A connection-local alias MUST NOT replace a core resource identity. Authentication of a connection does not replace the current permission check for a resource.

| State | Lifetime and owner |
| --- | --- |
| Session tuple, saved history, retry decisions, and terminal outcomes | Host resources, under the declared durability contract. Connection replacement does not delete them. |
| Applied state, applied cursor, and unresolved command intent | Client recovery state. The client saves state with its cursor. |
| Authentication, selected contracts, delivery keys, pending request IDs, queues, and live attachments | Connection state. Fresh setup creates new connection state. |
| Signed grants, revocation, expiry, and shared extension accounting | Their selected contract. Connection replacement MUST NOT renew them or reset shared limits. |

A host that routes a session to different workers MUST preserve one coherent session history and one retry decision for each command identity. It MUST NOT use a connection change to create a second admission. The deployment can use a durable store or another declared mechanism; this contract does not select a database or worker architecture.

After a connection loss, the client MUST retain the original session tuple, saved applied cursor, and unresolved command identity and semantic input. It MUST complete fresh authenticated selection before recovery. Current permission, expiry, and the session's saved protection floor still apply. Reconnection is not proof that a previous command failed or succeeded. The declared host durability contract determines what survives a host restart.

## Session isolation and failure {#dasp-conn-002}

Requirement group **DASP-CONN-002**.

A deployment that requires independent session failure and close boundaries on the current WebSocket binding MUST use a separate connection and driver for each session. It MUST NOT claim independent network delivery from several logical queues that share one WebSocket writer.

Several sessions MAY share a WebSocket connection. Their saved sequences and applied cursors remain separate. All attachments on that connection still end when it closes. The existing rules for an open timeout, read permission revocation, and client buffer overflow still require connection close. A session output queue does not reduce those close boundaries.

A driver with a configured session scope MUST reject requests and received events for another session before their application. A `failure` has no core `session_id`; its unique pending request ID supplies its context. Replies MUST also match the original request context. Connection-local checks do not replace host permission checks.

A binding with independent streams MUST define the authenticated mapping from streams to sessions, request correlation, open and resync order, stream failure, connection failure, and late output. It MUST preserve the core recovery rules. Those definitions require a separate exact binding contract. Sending the current WebSocket binding over HTTP/3 does not assign a QUIC stream to each DASP session.

## Bounded and fair output {#dasp-conn-003}

Requirement group **DASP-CONN-003**.

The host MUST bound queued output by message count and bytes for each connection and session. It MUST count an active write until its local result is known. It MUST also bound framing and encryption buffers in the driver. Logical JSON byte limits do not bound encrypted carrier memory by themselves.

When sessions share a writer, the host MUST give each eligible session a finite opportunity to release output. It MUST preserve the enqueue order within each session. Control preference MUST NOT move a resync notice or open confirmation ahead of an earlier required event for that session. The control burst MUST be finite when ordinary output is eligible.

The host MUST reserve output capacity for `session.opened`, `receipt`, `failure`, and `resync.required`. Saved pushes and temporary progress MUST NOT consume that reserve. Read replies are ordinary output in the supplied queue. They remain required replies: an overflow cannot silently discard them. Reserves MUST remain inside the total memory bounds. Their configured size MUST account for the selected control message sizes. If a required reply or resync notice cannot fit or be released, the host MUST follow the binding's resync or close rules.

Temporary `progress` MAY be dropped or replaced by newer matching progress. Such replacement MUST NOT cross another event in the session queue. Saved history, outcomes, and retry records MUST NOT be deleted to free output capacity. On resync, discard unsent update and progress output for the stopped attachment. Keep direct replies separate. An active write requires a separate driver decision before the resync notice; no old attachment output may follow that notice.

Scheduling MUST occur before delivery encryption. The driver MUST check current permission at the output release boundary. It MUST assign encrypted record numbers in actual release order and obey the selected encryption contract. An uncertain write MUST NOT cause reuse of a delivery record number. Fresh connection keys and setup are required where that contract requires them.

Flow-control credit, a queue lease completion, a successful socket write, and a transport acknowledgment MUST NOT establish command admission, command completion, or application of a saved event. Only the existing core evidence and saved client cursor have those meanings. This draft adds no application acknowledgment message.

## Graceful drain {#dasp-conn-004}

Requirement group **DASP-CONN-004**.

A local drain MUST stop new request admission to that connection and retain a fixed deadline. Later drain calls MUST join the first drain; they MUST NOT extend its deadline. The driver MAY finish requests already accepted for dispatch or reject requests that it can prove were not handed off. It MUST keep receiving pending replies and run their ordered callbacks before a normal closed notice.

When pending requests and accepted local work have finished, the driver MUST close the connection. It MUST close at the drain deadline if work remains. Callback work and physical shutdown MUST be bounded. A driver MUST enforce its connection and write deadlines outside a callback that can block the dispatcher. The Elixir managed WebSocket client supplies an independent physical drain guard. Functional owners and TypeScript application drivers must supply their own physical deadline mechanism.

Drain waits for local exchanges, not terminal command outcomes. A `receipt` can finish an exchange while the admitted command continues on the host. Neither drain nor close cancels that command, deletes its history, expires a grant early, or clears a selected extension reservation. Live delivery ends on close. Recovery uses the saved applied cursor.

If command handoff or admission is unresolved when the connection closes, the client MUST retain the original command identity and semantic input. It MAY submit that same intent through fresh authenticated setup with a new request ID and current valid authority evidence. It MUST NOT assign a new command ID merely because the receipt was lost. No automatic retry or external exactly-once guarantee is added.

A host shutdown MUST stop new admission, bound remaining output work, and preserve already admitted resources under its durability contract. This draft defines no peer drain notice. A coordinated peer shutdown message, if later required, belongs to a versioned binding and authenticated setup. HTTP GOAWAY is not a DASP core message.

## Fresh setup and early data {#dasp-conn-005}

Requirement group **DASP-CONN-005**.

Both peers MUST finish fresh authentication and exact mutual selection before any core operation on a new connection. They MUST NOT send or process a core event as TLS or QUIC early data. This includes reads and `session.open`, as well as commands. A local readiness callback can check driver state; it cannot authenticate a peer or establish selection by itself.

A driver MUST check readiness before request handoff and before processing received core traffic. If setup becomes invalid while local callbacks wait, the driver MUST prevent subsequent handoff or application. It MUST close a channel that has lost its established security context. Readiness does not replace the current permission check on each host operation and protected output release.

Session recovery MUST meet the saved protection floor for encryption, authority, and other selected extensions. Connection replacement MUST NOT enable silent feature removal, broader grants, or weaker algorithms. Existing retry comparison still uses the original semantic command input.

## Transport evolution and remaining work {#dasp-conn-006}

Requirement group **DASP-CONN-006**.

Bindings MUST preserve core identities, admission, retry, outcome, history, and cursor semantics when the transport changes. Transport-specific stream IDs, compression, flow control, health checks, and network addresses belong to their binding contracts.

The current implementation uses the selected WebSocket contract and separate connections when independent session failure is required. Native HTTP/2 or HTTP/3 streams, QUIC path migration, setup wire messages, shared limit fields, host health checks, and a running durable host remain separate binding work. They are not implemented by this draft or the supplied queue.

A later QUIC binding can define path migration while its authenticated connection remains valid. Migration MUST NOT change the session tuple, reset retry records, renew authority, or advance a cursor. A lost connection or host restart still requires the appropriate fresh setup and core recovery. Independent QUIC streams share connection resources and congestion; stream isolation is not a guarantee of independent total capacity.

## Client and queue use

Use `sessionId` in TypeScript or `session_id` in Elixir with a separate selected connection for that session. If the option is omitted, the existing shared connection behavior remains available.

Use `isReady` or `is_ready` to read driver state. Return `true` only after authentication, exact mutual selection, and the early-data phase have finished. If the option is omitted, the existing API still requires an already authenticated and selected channel. No setup implementation is supplied.

TypeScript:

```ts
const duplex = new DuplexTransport({
  hostSource,
  sessionId,
  isReady: () => driver.ready,
  send: wire => driver.sendCore(wire),
  close: () => driver.close(),
  onEvent: saveOrderedCheckpoint
});
// Use duplex.transport for Client. Feed verified core JSON to duplex.receive.
await duplex.drain(10_000);
```

Elixir:

```elixir
{:ok, pid} = DASP.Duplex.start_link(
  host_source: host_source,
  session_id: session_id,
  is_ready: fn -> Driver.ready?(driver) end,
  send: fn wire -> Driver.send_core(driver, wire) end,
  close: fn -> Driver.close(driver) end,
  on_event: &save_ordered_checkpoint/2
)
channel = DASP.Duplex.channel(pid)
# Use DASP.Duplex.transport(channel) for Client.
:ok = DASP.Duplex.drain(channel, 10_000)
```

The examples require an application driver. `send` hands off one event and does not await a reply. Callbacks must finish within driver deadlines and must not await new client requests. These legacy Elixir dispatcher callbacks run in one GenServer; they cannot enforce a physical close deadline while blocked. The new managed WebSocket API uses the functional connection engine and an independent deadline guard. Its application callbacks run in stream consumers. TypeScript physical close can start at the deadline, but the drain promise still waits for ordered callback and close completion. A resolved drain does not establish remote admission or completion. Inspect the closed notice for `drained`, `drain_timeout`, or another close cause.

Host output queue defaults:

| Setting | TypeScript option | Elixir option | Default |
| --- | --- | --- | --- |
| Connection message bound | `maxMessages` | `max_messages` | 128 |
| Connection logical byte bound | `maxBytes` | `max_bytes` | 2,097,152 |
| Session message bound | `maxSessionMessages` | `max_session_messages` | Smaller of 32 and the connection bound |
| Session logical byte bound | `maxSessionBytes` | `max_session_bytes` | Smaller of 524,288 and the connection bound |
| Reserved control messages | `reservedControlMessages` | `reserved_control_messages` | 8 |
| Reserved control bytes | `reservedControlBytes` | `reserved_control_bytes` | 65,536 |
| Maximum control burst | `maxControlBurst` | `max_control_burst` | 8 |

These are local helper defaults. They are not selected wire limits. Configure them for the binding's output sizes and memory policy. A small session byte bound can refuse a valid large reply; the driver must handle that refusal. Control output is also subject to session and total bounds.

Create `OutputQueue` in TypeScript or call `DASP.OutputQueue.new/1` in Elixir. The Elixir queue is immutable; use the returned queue after each operation. One driver must own its write order. `enqueue` validates and owns one logical core event. Supply the correlated session identity for a `failure`, which has no core session field. Only progress can return a dropped result. Other capacity failures return `overflow`; the driver must resync or close.

`take` gives at most one active delivery lease. Check current permission, frame or encrypt the event, and hand it to the bounded writer. Call `complete` only after a known local write result or a known discard before handoff. If handoff is uncertain, close and recover under the binding rules. `discardUpdates` or `discard_updates` removes queued attachment data for resync; it does not remove an active lease, direct replies, or host records. `close` discards local delivery state only.

The [private behavior cases](../../conformance/private/connection-management-cases.md) separate executable client and queue tests from host cases that have not been executed.

## Design sources

HTTP separates request semantics from connection state: [RFC 9110, section 3.3](https://www.rfc-editor.org/rfc/rfc9110.html#section-3.3). HTTP/2 defines streams and flow control while it retains HTTP semantics: [RFC 9113, sections 2 and 5.2](https://www.rfc-editor.org/rfc/rfc9113.html#section-2). HTTP/3 defines QUIC streams and graceful shutdown: [RFC 9114, sections 6 and 5.2](https://www.rfc-editor.org/rfc/rfc9114.html#section-6). QUIC defines connection migration: [RFC 9000, section 9](https://www.rfc-editor.org/rfc/rfc9000.html#section-9). Early data has replay risks: [RFC 8470, section 2](https://www.rfc-editor.org/rfc/rfc8470.html#section-2). DASP uses these lessons in its own binding rules; it does not adopt their frames as core messages.
