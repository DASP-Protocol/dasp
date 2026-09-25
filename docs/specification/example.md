# Source examples

Use the imported examples and fixtures:

- [Exact Phoenix frame fixtures](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/frames.json)
- [Valid and invalid value vectors](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/vectors.json)
- [Portable replay vectors](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/replay-v1/vectors.json)
- [Standalone Elixir consumer](../../upstream/seigyo/apps/jido_seigyo/examples/standalone/README.md)

The normal flow is join, open, submit, keep the admission Receipt, apply saved Updates, and read the View or Result. A reconnect resumes from saved state and the last applied Update cursor.

The JSON-RPC counter example from the initial proposal is archived. It is not a valid example of the imported protocol.
