> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Security and version rules

## Security

Remote connections MUST use authenticated, encrypted transport. Local test environments MAY use unencrypted loopback connections. Credential exchange belongs to a deployment profile. This draft does not define a token issuer or login method.

The host MUST authorize every session operation and every subscription update. Possession of an actor, session, command, or subscription identifier does not grant access. If access is revoked, the host MUST stop protected updates; it closes the connection so that the client detects loss of its live view. Reconnection requires current authorization.

A host MAY use `NOT_FOUND` instead of `FORBIDDEN` to conceal resource existence. It MUST use a consistent policy. Multi-tenant hosts MUST isolate identifiers, command records, state, and subscriptions by tenant. Clients MUST partition cached data by service and authenticated identity.

Browser-facing hosts MUST validate the WebSocket Origin against their configured policy. Deployments MUST keep credentials out of URLs and application logs. Hosts MUST bound message size, pending requests, subscription count, and output queues. Quotas MUST NOT cause deletion of retained command records while a session remains available under this draft.

## Versions

The proposed identifier is `0.1.0-draft.1`. It is not a release claim. Peers negotiate exact identifiers during initialization and keep the selected version for the connection lifetime. A version number alone does not prove compatibility.

Unknown methods produce a method-not-found error. Receivers MAY ignore unknown optional object fields. They MUST reject missing required fields and invalid field types. New behavior that changes interpretation of existing messages requires a new negotiated version. Application schemas require their own version policy.

The first draft defines no optional feature negotiation. Extensions cannot change the core guarantees. A future draft will define capability negotiation before optional wire extensions are standardized.

The specification and each language client have separate release versions. A client release MUST list its supported protocol versions. Proposed tags are `spec/vVERSION`, `elixir/vVERSION`, and `typescript/vVERSION`. No package names are reserved by this document.
