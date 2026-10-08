# Define a profile and binding

DASP supplies the session rules. Your application still needs a vocabulary and a delivery path.

## Profile: what the work means

A profile defines its complete command capability universe and marks each command as required or optional. It defines command names, input and output schemas, application events, and state. It also defines concurrency, cancellation, errors, and the boundary of completion.

For example, `counter.add` accepts an amount and returns a value. An agent profile could define `task.run`. These are application commands, not built-in DASP operations.

Start with the [counter profile](../specification/example.md). Give your profile an immutable URI and version. Include valid examples, invalid examples, and behavior checks.

One actor has one exact profile URI and version for its lifetime. The actor's
effective set contains all required commands and the optional commands that it
activates. An advertised view can filter this set for one authenticated
context. It cannot add or activate a command, and it does not grant permission.

When discovery is selected, capability details identify complete input and
output contracts as full JSON Schema 2020-12 resources. Publish a closed
resource manifest and exact bytes for every required resource. A schema URI is
an identifier. It is not permission to fetch network content.

Be precise about completion. Passing tests, saving an artifact, and receiving approval are different facts. State which facts your command requires.

## Binding: how messages travel

A binding defines endpoints, authentication, host authority, framing, request/reply routing, and timeouts. It also defines limits, replay paging, reconnect behavior, and any live subscription handoff.

For capability discovery, the binding also defines the setup envelope,
authentication, exact contract selection, framing, correlation, resource-byte
transfer, timeouts, close behavior, and finite limits. Discovery selection
finishes before the first discovery operation. After discovery, the peers
confirm the profile, core, binding, extensions, and limits before any core
operation.

Select the exact core and profile versions before accepting application work. The CloudEvents `source` identifies producer context; it is not a destination URL.

DASP does not require HTTP, WebSocket, or a broker. No production binding is released. Choosing a transport is only the first step; clients and hosts must agree on its behavior.

The first [WebSocket delivery contract](../specification/websocket-live-delivery.md) starts observation through session open and recovers through saved replay. Optional [encryption](../specification/payload-encryption.md) protects the complete core event. Optional [proof of authority](../specification/proof-of-authority.md) carries signed grants outside profile input. Use the [extension contract](../specification/extensions.md) to define identity, version, dependencies, scope, settings, and conformance. Both peers must authenticate and confirm the selection before session open. Save the session's protection requirements and enforce them on every later connection. See [protocol capabilities](../specification/capabilities.md) for implementation status and release requirements.

## Keep the common guarantees

A profile cannot redefine acceptance as completion. A binding cannot discard command identity or skip saved events during recovery.

Keep each fact separate: discovery describes commands, a profile defines their
meaning, authority can permit work, admission saves intent, and encryption
protects content. One fact does not prove another.

Use the [profile and binding requirements](../specification/profiles-and-bindings.md) as your implementation checklist. Then [check the available conformance evidence](../../conformance/README.md).
