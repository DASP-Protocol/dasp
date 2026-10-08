# Start building

Start at the boundary you own: the client that requests work, or the host that runs it.

DASP has experimental Elixir and TypeScript clients. You can run their recorded examples today. A production binding and persistent example host are still to be built.

## Connect a client

Use a [language client](../../clients/README.md) to construct requests, check replies, discover capabilities, and apply saved updates. Supply authenticated setup, profile validation, and durable storage. The Elixir client includes a WebSocket implementation. The TypeScript client uses an application transport.

Choose [Elixir](../../clients/elixir/README.md) or [TypeScript](../../clients/typescript/README.md). Each page includes a recorded example, setup, and API details.

## Expose an actor

[Implement a host](host.md) around your actor runtime. The host owns admission, saved outcomes, and recovery. Its storage must preserve those decisions before it reports success.

[Define a profile and binding](profiles-and-bindings.md) so both sides agree on commands and delivery.

If the binding selects capability discovery, expose the actor's exact profile,
bounded summary pages, selected details, and exact schema resources before
normal profile confirmation. [Review the discovery flow](../guide/capability-discovery.md).

## Inspect the contract first

[Follow a command](walkthrough.md) to see complete messages and recovery. Then use [the specification](../specification/README.md) for requirements and [conformance coverage](../../conformance/README.md) for the evidence behind each check.
