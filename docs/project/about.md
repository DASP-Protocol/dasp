# About DASP

DASP grew out of a practical integration problem: the actor keeps working, but its client disconnects. The next connection needs a reliable account of what happened.

[Mike Hostetler](https://mike-hostetler.com) extracted the session contract from work on [Jido](https://jido.run) and its agent tooling. Publishing it gives other builders something concrete to inspect, test, and challenge.

## A common boundary

The goal is a shared contract between an actor host and its clients. Commands, saved outcomes, and recovery should have the same meaning across languages.

Jido and the [BEAM](https://www.erlang.org) informed the work. DASP does not require either. The [Elixir client](../../clients/elixir/README.md) uses [Jido Signal](https://github.com/agentjido/jido_signal); the protocol and [TypeScript client](../../clients/typescript/README.md) remain independent of that library.

## Open for review

DASP is a working draft. The next useful evidence is an implementation that can survive the failure cases in the contract.

If you are building a similar system, bring a concrete example: a command, a failed connection, or a recovery rule that does not fit. [Share feedback](https://github.com/DASP-Protocol/dasp/issues) or review [status and open decisions](feedback.md).

The [DASP-Protocol organization](https://github.com/DASP-Protocol) maintains the project. Maintainers review changes to the core, profiles, bindings, and clients. The project license is still being selected.

[Contributing](../../CONTRIBUTING.md) · [Changes](../../CHANGELOG.md) · [Security reporting](../../SECURITY.md)
