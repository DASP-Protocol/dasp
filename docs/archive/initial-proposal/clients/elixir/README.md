> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Elixir client plan

Status: planned. No Hex package is published by this repository.

Use a supervised connection process to manage requests and subscriptions. Keep application actors separate from the client connection process. A supervisor restart must not create new command identifiers for unresolved work.

Return success and structured error tuples through the public API. Deliver snapshots with their subscription identifier. Define how a subscriber process stops a subscription and how the client bounds its mailbox. A local process failure must not close a durable session unless the caller requests close.

Keep JSON object keys as strings. Do not convert untrusted keys to atoms. Encode revisions as decimal strings even though Elixir can store large integers. Use explicit JSON encoding for application structs.

Before release, select the WebSocket and JSON libraries, define the OTP support range, add a Mix project, and run every shared conformance case. The Elixir implementation does not define server-side actor requirements.
