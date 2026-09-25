# Worked example: a counter actor

This example uses an illustrative profile, `urn:example:dasp:counter`, version `1`. It does not require chat messages or a particular language.

The profile starts a session-local counter at zero. `counter.add` accepts exactly `{ "amount": integer }`, where amount is between −1,000,000 and 1,000,000. The host processes commands serially and rejects an addition that would exceed the safe integer range. A completed outcome contains exactly `{ "value": integer }`. The view has the same state shape. `counter.changed` publishes the new value.

Completion means the addition and its new state are saved. It says nothing about external systems. This example profile does not support cancellation. Optional `counter.working` progress has an empty object payload.

## Issue intent

Open the session with actor ID `counter-main`, session ID `session-counter`, and the profile above. Then send:

```json
{
  "specversion": "1.0",
  "id": "event-3",
  "source": "urn:example:client:one",
  "type": "dasp.command.v1",
  "datacontenttype": "application/json",
  "requestid": "request-add",
  "data": {
    "session_id": "session-counter",
    "command_id": "command-add-1",
    "name": "counter.add",
    "input": { "amount": 3 }
  }
}
```

The binding supplies authentication and destination routing. The source URI does neither.

## Observe saved evidence

The host saves admission at sequence 1. The receipt reports `accepted` and `admission_sequence: 1`. It is not the addition's result.

| Sequence | Kind | Saved meaning |
| --- | --- | --- |
| 1 | `command.accepted` | `counter.add` was admitted |
| 2 | `application` | `counter.changed`, with `{ "value": 3 }` |
| 3 | `command.outcome` | Completed, with output `{ "value": 3 }` |

These facts have separate immutable event identities. A transport can deliver the receipt after a live update; request correlation does not impose a global delivery order.

## Recover

Suppose the client saved cursor 1 before losing its connection. It reads after 1. The page contains the original events at sequences 2 and 3, with their original CloudEvents IDs. It reports `after: 1`, `next: 3`, and `head: 3`.

The client applies each fact and saves cursor 3 with its projection. Another client can read the same facts with its own cursor.

If the admission reply was lost, the client resubmits the same command ID, name, session, and input with a new request ID. The host returns `duplicate` with admission sequence 1. It does not add 3 again. Changing amount to 4 under that command ID is a conflict.

## Inspect the fixtures

The [complete JSON exchange](../../specification/draft-01/examples/counter.json) includes every core event type. It is an example set, not a transport transcript. The [core schema](../../specification/draft-01/envelope.schema.json) checks generic shapes. The [counter payload schema](../../specification/draft-01/examples/counter-profile.schema.json) checks the illustrative profile.

Run `npm run spec:check` to validate these fixtures and selected negative and cross-message cases. These are specification checks, not live host conformance.
