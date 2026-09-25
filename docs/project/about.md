# About DASP

DASP is the **Durable Actor Session Protocol**: a language-independent server protocol for agent builders. It defines how clients send commands to actors, read saved outcomes, and recover a shared session after a connection fails.

## Origin

DASP grew out of **Mike Hostetler’s** work on the [Jido project](https://jido.run), an Elixir framework for building agents.

Jido builds on the BEAM runtime and OTP’s process and supervision model. Work with these actors and agents raised a practical need: clients must be able to return to the same actor, retry a command safely, and read what happened while they were disconnected.

Process supervision can restart a failed process. Durable session recovery also needs saved command records, outcomes, and history. DASP defines the server contract for those records.

## A protocol across languages

DASP carries these requirements into a generic CloudEvents-based specification. Applications define their own commands and results. Servers and clients can use any language or runtime; Jido, Elixir, and the BEAM are not required.

Elixir and TypeScript are the first planned client languages. The project keeps the specification, shared checks, documentation site, and client work in one repository.

## Open for feedback

DASP is a working draft. Feedback on the model, recovery rules, examples, and missing use cases will help shape it.

[Share feedback through GitHub Issues](https://github.com/DASP-Protocol/dasp/issues). Include the situation you need to support and the rule or example that needs to change. The [review questions](feedback.md) list current open decisions.

## Project stewardship

The [DASP-Protocol organization](https://github.com/DASP-Protocol) maintains the project. Changes are reviewed in [the public repository](https://github.com/DASP-Protocol/dasp). Maintainers decide whether a proposed change belongs in the core, a profile, a binding, or an implementation.

The current contract is a working review draft. A passing artifact check does not establish implementation conformance.

## Contribute

Read [Contributing](../../CONTRIBUTING.md). A protocol change needs a requirement, a schema or validation rule where applicable, examples, and updated coverage. Record unresolved behavior as an open decision rather than a hidden implementation choice.

See [review questions](feedback.md), [release preparation](releases.md), and [security reporting](../../SECURITY.md).

## License status

The project license is being selected before the first specification release. The bundled font retains its existing license.
