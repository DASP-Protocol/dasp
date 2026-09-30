# Define a profile and binding

DASP supplies the session rules. Your application still needs a vocabulary and a delivery path.

## Profile: what the work means

A profile defines command names, input and output schemas, application events, and state. It also defines concurrency, cancellation, errors, and the boundary of completion.

For example, `counter.add` accepts an amount and returns a value. An agent profile could define `task.run`. These are application commands, not built-in DASP operations.

Start with the [counter profile](../specification/example.md). Give your profile an immutable URI and version. Include valid examples, invalid examples, and behavior checks.

Be precise about completion. Passing tests, saving an artifact, and receiving approval are different facts. State which facts your command requires.

## Binding: how messages travel

A binding defines endpoints, authentication, host authority, framing, request/reply routing, and timeouts. It also defines limits, replay paging, reconnect behavior, and any live subscription handoff.

Select the exact core and profile versions before accepting application work. The CloudEvents `source` identifies producer context; it is not a destination URL.

DASP does not require HTTP, WebSocket, or a broker. No production binding is released. Choosing a transport is only the first step; clients and hosts must agree on its behavior.

The first [WebSocket delivery contract](../specification/websocket-live-delivery.md) starts observation through session open and recovers through saved replay. Optional [encryption](../specification/payload-encryption.md) protects the complete core event. Optional [proof of authority](../specification/proof-of-authority.md) carries signed grants outside profile input. Select and authenticate required capabilities before sending work. See [protocol capabilities](../specification/capabilities.md) for implementation status and release requirements.

## Keep the common guarantees

A profile cannot redefine acceptance as completion. A binding cannot discard command identity or skip saved events during recovery.

Use the [profile and binding requirements](../specification/profiles-and-bindings.md) as your implementation checklist. Then [check the available conformance evidence](../../conformance/README.md).
