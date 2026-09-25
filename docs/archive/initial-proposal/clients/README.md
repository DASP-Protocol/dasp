> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Language clients

All clients belong in this repository. Elixir and TypeScript are the first targets. Both are planned; neither is implemented.

A client MUST implement the same [wire contract](../docs/specification/messages.md) and [recovery rules](../docs/specification/recovery.md). Native APIs can differ. Package versions are independent of protocol versions.

Each client must provide connection initialization, session open/read/close, command send/result lookup, snapshot subscription, and unsubscribe. It must expose structured errors and distinguish an unknown command outcome from a confirmed rejection.

The caller must be able to provide and recover `sessionId` and `commandId`. Automatic retries must preserve command content and identity. Persistent retry storage is optional, but a client must state whether unresolved commands survive a client process restart.

A client must preserve opaque strings, decimal revision strings, JSON null values, and application payloads. It must not expose native process identifiers or language exceptions on the wire. A wire value that the native runtime cannot represent safely must produce an explicit error, not silent data loss.

Both clients will use shared fixtures and the same host failure tests. Native unit tests do not replace cross-language conformance tests.

| Target | Intended interface | Plan |
| --- | --- | --- |
| [Elixir](elixir/README.md) | OTP-managed connection and process messages | First release target |
| [TypeScript](typescript/README.md) | Async requests and subscription iterator | First release target |
