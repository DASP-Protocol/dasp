# Implement a host

The host owns the record. Its job is to make that record survive a failed connection or process.

You choose the actor runtime, scheduler, and storage. DASP defines what a client can rely on.

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

Use [admission and recovery](../specification/recovery.md) as the authority. Define the application contract with [a profile and binding](profiles-and-bindings.md).
