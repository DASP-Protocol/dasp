# Elixir client

Status: the imported client implements the source contract, not DASP draft-01. A new DASP client or explicit adapter must target the [generic CloudEvents core](../../docs/specification/README.md), a selected profile, and a specified binding.

The existing [Jido.Seigyo.Client](../../upstream/seigyo/apps/jido_seigyo/lib/jido_seigyo/client.ex) is imported with the [jido_seigyo package](../../upstream/seigyo/apps/jido_seigyo/README.md). Its transport, typed values, tests, schemas, and standalone consumer are included.

The client connects by WebSocket and exposes the coding profile. It supports saved Update replay and acknowledged delivery. After a WebSocket failure, the caller starts a new client and resumes from saved application state.

The package remains at its original path to preserve the source snapshot. Its Mix file still uses umbrella and sibling dependency paths. Elixir compilation and live server tests have not been run in this project. Extracting a separately releasable DASP client requires dependency and package work; the import does not make that claim.

Start with the [standalone consumer](../../upstream/seigyo/apps/jido_seigyo/examples/standalone/README.md) and [client tests](../../upstream/seigyo/apps/jido_seigyo/test/client_tests/client_test.exs).
