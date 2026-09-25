# TypeScript client

Status: not implemented. Use the imported [client proposal](../../upstream/seigyo/docs/seigyo/client-design.md).

Implement the existing Phoenix Channel frames first. Validate Signals against the same closed schemas and custom rules as the Elixir client. Preserve safe integer bounds, typed IDs, admission and outcome separation, and applied Update cursors.

Use the [shared fixtures](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/contract.json) and [replay vectors](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/replay-v1/vectors.json). Keep UI code outside the client package. Do not use the superseded JSON-RPC draft as the implementation contract.
