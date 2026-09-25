> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Recovery and durability

## Commit boundary

The host MUST atomically persist the command identity, command content, terminal outcome, and affected actor and session state before it returns command success. Notifications MUST describe committed state only.

If the host fails before commit, recovery MUST expose no partial state or successful outcome. If it fails after commit but before response, a retry MUST return the original outcome. The host MUST prevent concurrent owners from committing divergent actor histories. Leader election, leases, fencing, and storage transactions are implementation choices.

Durability means that acknowledged records survive host process restart. Each deployment MUST document its storage failure model, including disk loss and regional loss. The draft does not promise survival beyond that declared model.

## Duplicate commands

The duplicate key is `(sessionId, commandId)`. Authorization MUST be checked before access to a stored result. Command identity does not depend on a connection or a JSON-RPC request identifier.

Command content consists of `name`, `input`, and the presence and value of `expectedRevision`. Object member order is insignificant. Array order and string content are significant. JSON numbers compare by mathematical value. An implementation MUST use a representation that preserves this comparison; lossy conversion of large numbers is not sufficient. Applications SHOULD encode exact large numbers as strings.

The host MUST ensure that concurrent duplicates cannot produce two commits. It MAY wait for the first attempt or return `BUSY` while that attempt is pending. A completed duplicate receives the stored outcome even if the session revision or status has since changed.

For a valid new command on an accessible session, `SESSION_CLOSED`, `REVISION_CONFLICT`, and `COMMAND_REJECTED` are terminal outcomes. The host MUST store them under the command identifier before returning them. Their retries return the same error. A revised command requires a new identifier.

Parameter errors, authorization failures, missing sessions, resource limits, and transient internal errors do not create terminal command records. Clients can retry transient failures with the same content and identifier. Internal errors do not prove that commit failed.

## Reconnect procedure

1. Establish and authenticate a new connection.
2. Complete `initialize` for a supported version.
3. Subscribe again to each required session.
4. Replace each local view with the returned snapshot.
5. Look up unresolved commands with `session.result`.
6. Retry unknown commands with their original identifiers and content.

A command result can refer to an older revision than the new snapshot. Clients MUST NOT roll back state to that revision.

Within a subscription, the client expects the next revision to be exactly one greater. On a gap, invalid update, or unknown required state shape, it MUST stop presenting the view as current and obtain a new subscription snapshot. Clients MUST route updates by subscription identifier and discard updates from a retired connection.

A snapshot restores current state. It does not deliver every historical business event. Applications that require durable event consumption need a separate event-log contract, which this draft does not define.

## External effects and cancellation

DASP provides one durable command outcome per duplicate key. It does not promise exactly-once effects in an external system.

An actor that sends payments, email, or other external operations SHOULD persist an outbox record in the same transaction as its state. The worker SHOULD use a stable effect identifier and the external service's duplicate protection. If the external service cannot prevent duplicates, the application MUST document that limit.

A client timeout stops waiting locally. It MUST NOT be reported as confirmed command cancellation. Command cancellation and long-running job progress are outside the core draft. Applications can define durable job actors and separate commands to request cancellation.
