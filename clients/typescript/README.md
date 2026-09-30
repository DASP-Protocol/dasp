# TypeScript client

Experimental `@dasp-protocol/client`, version `0.1.0-draft.1`, for DASP `draft-01`. Node.js 22 or later; ESM. No npm release or browser support claim is made. The project license is pending.

## Run the recorded example

From the repository root:

```sh
cd clients/typescript
npm ci
npm run example
```

See [recorded.mjs](examples/recorded.mjs). It exercises the client with a local reply adapter. It does not provide a server or a network binding. See the [shared client guide](../README.md) for test coverage and limits.

## Install a review archive

Build from the repository root:

```sh
npm --prefix clients/typescript ci
npm --prefix clients/typescript test
mkdir -p dist/client-packages
cd clients/typescript
npm pack --pack-destination ../../dist/client-packages
cd ../..
```

In a separate application, run `npm install /absolute/path/to/dasp-protocol-client-0.1.0-draft.1.tgz`. CI also provides archives as [workflow artifacts](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml).

## Connect an application

```ts
import { Client, type Session, type Transport, type ProfileValidator } from "@dasp-protocol/client";

// Your adapter supplies an authenticated channel, binding selection, and framing.
declare const transport: Transport;
declare const validateProfile: ProfileValidator;

const client = new Client({
  source: "urn:example:client:one",
  hostSource: "urn:example:host:one",
  transport,
  validateProfile,
  timeoutMs: 10_000
});
const session: Session = {
  session_id: "session-counter",
  actor_id: "counter-main",
  profile: { id: "urn:example:dasp:counter", version: "1" }
};
await client.open(session);

// Save this identity and exact input before the first attempt.
const command = { command_id: "command-add-1", name: "counter.add", input: { amount: 3 } };
const receipt = await client.submit(session, command);
// The receipt is not a completed outcome.
const outcome = await client.readOutcome(session, command.command_id);
```

The transport signature is `(json, { signal }) => Promise<string | Uint8Array>`. Return the complete UTF-8 structured reply. Do not parse it first: that can discard duplicate keys or round numbers. A deadline aborts the signal and rejects the call. There are no automatic retries.

The profile validator receives a copy of each event. Return `true` only when it is valid for your selected profile. It runs before send and after receive, including each update within a replay page. Throwing or returning `false` stops the operation. Use a separate configured client if the application needs different profile validators.

## API

| Method | Reply |
| --- | --- |
| `open(session)` | `session.opened` |
| `submit(session, command)` | Admission `receipt` |
| `readView(session)` | Coherent `view` |
| `readUpdates(session, after, limit = 100)` | Validated `updates` page |
| `readOutcome(session, commandId)` | Pending or settled `outcome` |
| `decode(json)` / `encode(event)` | Validated core event / JSON text |

Core decoding does not check application semantics or authenticate a producer. Use the client for request/reply checks. A transport adapter must authenticate push events before passing them to recovery code.

## Recover state

```ts
import { applyUpdates, checkpointFromView, type JsonObject, type Event } from "@dasp-protocol/client";

declare function reduce(state: JsonObject, event: Event<"update">): JsonObject;
declare function saveAtomically(checkpoint: unknown): Promise<void>;

const view = await client.readView(session);
let checkpoint = checkpointFromView(view, validateProfile);
await saveAtomically(checkpoint);
const page = await client.readUpdates(session, checkpoint.cursor);
const next = applyUpdates(checkpoint, page.data.events, reduce, validateProfile);
await saveAtomically(next);
checkpoint = next;
```

On restart, load the saved checkpoint instead of creating a new one. Open the same session and recover unresolved commands. For a polling-only binding, continue reading under its paging policy until `page.data.next === page.data.head`. For the [first WebSocket binding](../../docs/specification/websocket-live-delivery.md#dasp-ws-003), confirm the new attachment and retain its fixed head `H`. Buffer live events, replay through `H`, then apply the buffer in sequence. A newer page head does not move `H`. For example, saved cursor 3, `H = 6`, and page 4–6 with head 7 require one recovery read, then buffered event 7. An equal open of a retained attachment does not restart replay. Use `LiveRecovery` for this transition.

The reducer must be pure. A failed batch returns no new checkpoint. Duplicate evidence is retained in the checkpoint; it can grow with history. An old update with no retained evidence raises `missing_evidence`. Recover a trusted view or stop. Do not discard evidence and assume old records match.

Errors use `DASPError.code`: `invalid_json`, `invalid_event`, `configuration`, `transport`, `timeout`, `correlation`, `remote_failure`, `profile`, `replay`, `checkpoint`, `gap`, `changed_update`, or `missing_evidence`. A remote failure keeps the server error in `detail`. Transport failures and timeouts leave admission unresolved.


## Live delivery on a duplex channel

`DuplexTransport` connects the existing `Client` to a channel that can send requests and receive replies and pushes. `LiveRecovery` tracks one session on that connection. It retains a fixed replay head, checks live sequence numbers, buffers events during replay, and cancels obsolete recovery reads after `resync.required`. Normal live operation does not poll history.

The application must supply an authenticated channel with the binding already selected. Feed the original core JSON to `receive()` after authentication and decryption. The driver must limit frame assembly before it gives a complete message to the dispatcher. These modules do not open a WebSocket, select a binding, set up encryption, or send health checks. Those wire formats need a separate specification and implementation.

The example below uses the `session`, `reduce`, `validateProfile`, and `saveAtomically` functions from the examples above. `savedCheckpoint` is a trusted checkpoint loaded from storage or made from a trusted view. The channel functions are application functions.

```ts
import { DuplexTransport, LiveRecovery, type Checkpoint } from "@dasp-protocol/client";

declare const savedCheckpoint: Checkpoint;
declare function sendCore(json: string): Promise<void>; // Hand off; do not wait for a reply.
declare function closeChannel(): Promise<void>;

let live = new LiveRecovery({ checkpoint: savedCheckpoint,
  clientSource: "urn:example:client:one", reduce, validateProfile });
const duplex = new DuplexTransport({
  hostSource: savedCheckpoint.hostSource,
  send: sendCore,
  close: closeChannel,
  onEvent: async notice => {
    if (notice.kind === "closed") { live = live.close(); return; }
    if (notice.kind === "timeout") { live = live.timeout(notice.requestid); return; }
    const next = notice.kind === "sent"
      ? live.sent(notice.wire, { replay: notice.event.type === "dasp.v1.updates.read" && live.phase === "replay" })
      : live.received(notice.wire);
    if (next.action === "save") await saveAtomically(next.checkpoint);
    live = next;
    duplex.cancel(live.cancelledRequests);
  }
});
const liveClient = new Client({ source: "urn:example:client:one",
  hostSource: savedCheckpoint.hostSource, transport: duplex.transport, validateProfile });

// The driver calls and awaits duplex.receive(coreJson) for each incoming message.
await liveClient.open(session);
for (let read = live.nextRead(); read; read = live.nextRead()) {
  await liveClient.readUpdates(session, read.after, read.limit);
}
// The incoming stream now supplies new updates. No periodic history read is needed.
```

Save state, cursor, session, host source, and duplicate evidence in one atomic operation. Install the returned recovery state only after the save succeeds. A callback error closes the connection and rejects pending requests. The old checkpoint remains available for recovery. The reducer must have no external side effects.

Run recovery control outside `onEvent`. The callback must not wait for a new request: replies use the same ordered queue. After a resync, `action === "reopen"` means open the same session again. `action === "wait-open"` means wait for the existing open reply. Then use `nextRead()` until it returns `null`. If open fails, decide whether to retry outside the callback. An open deadline closes the entire connection. Make new dispatcher and recovery objects on a new connection, using the saved checkpoint. Do not retry commands automatically.

Mark only recovery reads with `replay: true`. Ordinary explicit history reads do not change the checkpoint. The example reserves reads during replay for recovery. An application that also makes ordinary reads at that time must distinguish them in its callback. Progress is temporary and does not change the saved cursor. For several sessions, route each event to a separate `LiveRecovery`; use one dispatcher for the connection.

`cancel(ids)` rejects local requests and discards structurally valid late replies. It does not cancel server work. Cancelling a pending open closes the connection. Request IDs must be unique across the connection. `settled` waits for queued work known at the time of the call.

| Local limit | Default | Option |
| --- | --- | --- |
| Queued messages, including active callback work | 100 | `maxQueuedMessages` |
| Queued core JSON bytes | 1 MiB | `maxQueuedBytes` |
| Pending requests | 100 | `maxPendingRequests` |
| Request IDs retained for one connection | 4096 | `maxTrackedRequests` |
| Buffered live events during replay | 100 | `maxBufferedEvents` on `LiveRecovery` |
| Encoded buffered event bytes | 1 MiB | `maxBufferedBytes` on `LiveRecovery` |
| Events per recovery read | 100 | `pageLimit` on `LiveRecovery` |

Reconnect before the request tracking limit is reached. Queue or buffer overflow closes the connection through the dispatcher callback. A recovery transition error used without the dispatcher requires the application to close the connection. Additional error codes are `live`, `continuity`, `overflow`, `closed`, and `resync`.

Tests execute all 16 shared delivery traces against `LiveRecovery`. In-memory channel tests check reply ordering, replay overlap, cancellation, deadlines, storage failures, and local limits. They do not prove WebSocket host conformance or cryptographic interoperability.
