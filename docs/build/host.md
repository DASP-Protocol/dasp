# Implement a host

The host owns the record. Its job is to make that record survive a failed connection or process.

You choose the actor runtime, scheduler, and storage. DASP defines what a client can rely on.

## Describe the actor before session open

When a binding selects capability discovery, resolve one immutable profile for
the actor. Return a complete advertised view through bounded summary pages in
one stable snapshot. Do not send one unbounded catalog and do not silently
truncate the view.

Serve details only for selected exact capability identities. Serve each schema
resource as exact JSON Schema 2020-12 bytes from a closed manifest. Do not treat
a resource identity or schema URI as permission to fetch a network resource or
load code.

Apply current disclosure rules before every page, detail, resource, and release
reply. Scoped disclosure is not command authority. Enforce finite limits for
the complete view, each page, detail requests, resource bytes, schema closures,
live snapshots, and snapshot retention. Keep received presentation text and
schema annotations inert.

## Save before dispatch

Authorize the request and validate its profile. Save the command ID, complete retry data, and acceptance update as one recoverable decision. Only then expose acceptance and dispatch the work.

An equal retry returns the original admission. Reusing an admitted ID with changed input, name, or session is a conflict. Concurrent submissions must reach the same decision.

## Record the result

Commit each update before publishing it. Save at most one terminal outcome for an admitted command. A stale worker must not replace that outcome.

After worker or owner loss, reconcile saved admission with effect evidence before dispatch. If effects cannot be established, save `uncertain` and prevent unsafe repeat execution. External effects need application-level controls.

## Serve returning clients

Provide views at coherent cursors, outcome reads, and ordered replay pages. Keep saved event identities during replay. A live transport must define how replay joins live delivery without a gap.

Each authorized client has its own applied cursor. A shared session does not imply shared connection state.

## Establish the durability boundary

Draft-01 retains updates, outcomes, and retry records for the entire session lifetime. Reject new work when capacity is exhausted. Do not silently remove retry evidence.

Test process restart, concurrent retries, stale workers, and interrupted replay. State whether power loss and storage failures are covered. [Runtime test cases](../../conformance/behavioral-cases.md) describe the required failure scenarios; they are not an implemented host test runner.

Use [admission and recovery](../specification/recovery.md) as the authority. Use
the [capability-discovery contract](../specification/capability-discovery.md)
when the binding selects it. Define the application contract with [a profile
and binding](profiles-and-bindings.md).
