# TypeScript client

Experimental `@dasp-protocol/client`, version `0.1.0-draft.1`, for DASP `draft-01`. Node.js 22 or later; ESM. No npm release or browser support claim is made. The project license is pending.

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

On restart, load the saved checkpoint instead of creating a new one. Open the same session and recover unresolved commands. Continue reading until `page.data.next === page.data.head`. The adapter defines the safe transition to a live stream.

The reducer must be pure. A failed batch returns no new checkpoint. Duplicate evidence is retained in the checkpoint; it can grow with history. An old update with no retained evidence raises `missing_evidence`. Recover a trusted view or stop. Do not discard evidence and assume old records match.

Errors use `DASPError.code`: `invalid_json`, `invalid_event`, `configuration`, `transport`, `timeout`, `correlation`, `remote_failure`, `profile`, `replay`, `checkpoint`, `gap`, `changed_update`, or `missing_evidence`. A remote failure keeps the server error in `detail`. Transport failures and timeouts leave admission unresolved.

## Run the recorded example

```sh
npm run example
```

See [recorded.mjs](examples/recorded.mjs). It exercises the client with a local reply adapter. It does not provide a server or a network binding. See the [shared client guide](../README.md) for test coverage and limits.
