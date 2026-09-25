> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Design decisions

These are proposed choices for review, not released guarantees.

| Choice | Reason | Cost |
| --- | --- | --- |
| General durable actors | Supports services beyond AI agents | Applications must define their own commands |
| One actor per session | Makes identity and ordering explicit | Cross-actor workflows need application coordination |
| JSON-RPC over WebSocket first | Gives both clients one transport profile | Other transports need framing rules |
| Complete snapshots | Gives all languages the same state rules | Large state increases bandwidth |
| Per-session decimal revisions | Avoids JavaScript integer limits | Clients need explicit numeric comparison |
| Durable command records | Makes response-loss recovery safe | Records require storage for the session lifetime |
| Snapshot recovery first | Keeps reconnect behavior bounded | Does not provide historical event delivery |
| Text specification first | Keeps language bindings subordinate | Schemas and tests still need implementation |

## Questions before the first implementation release

1. Which actor applications and state sizes must the first release support?
2. Should sessions have owners, shared access, or both? Define one deployment authorization profile for interoperability tests.
3. What retention and deletion policy is required? A later expiry design must prevent an old retry from executing as new work.
4. Is current-state recovery sufficient, or is durable event replay required?
5. Are long-running commands represented as job actors, or does the protocol need accepted and completed states?
6. Which storage failure model must the first host demonstrate?
7. Which repository name, project license, npm package name, and Hex package name should be used?

## Implementation order

1. Review the core semantics and choose an application for examples.
2. Add language-independent JSON Schema and valid/invalid message fixtures.
3. Build a test host with durable storage and crash injection.
4. Build Elixir and TypeScript clients against the same fixtures and host.
5. Run the shared conformance matrix and document limits.
6. Publish a reviewed specification version and independent client releases.

An implementation result can require changes to this draft. Record each wire change and its reason before publishing a new draft identifier.
