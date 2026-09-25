> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Durable Actor Session Protocol

DASP defines how clients send commands to durable actors and observe session state across connection loss and host restart.

Project home: [DASP Protocol](https://github.com/DASP-Protocol).

**Status: design draft.** This repository contains a proposed protocol and client plans. It does not yet contain a working server or client. The draft identifier is `0.1.0-draft.1`. Wire formats and requirements can change before release.

DASP is language independent. Protocol requirements belong in the specification, not in Elixir or TypeScript source code. An actor does not require an Erlang process, a JavaScript object, an AI model, or a specific database.

## Read the documents

- [Documentation index](docs/README.md)
- [Core specification](docs/specification/README.md)
- [Message reference](docs/specification/messages.md)
- [Recovery and durability](docs/specification/recovery.md)
- [Example exchange](docs/specification/example.md)
- [Design decisions and open questions](docs/design/decisions.md)
- [Microsoft AHP reference](docs/design/ahp-reference.md)
- [Client requirements](clients/README.md)
- [Conformance plan](conformance/README.md)

## Repository structure

| Path | Purpose |
| --- | --- |
| `docs/specification/` | Language-independent protocol requirements |
| `docs/design/` | Design reasons, alternatives, and open questions |
| `clients/elixir/` | First Elixir client target |
| `clients/typescript/` | First TypeScript client target |
| `conformance/` | Shared behavior checks for all languages |
| `reference/agent-host-protocol/` | Local Microsoft AHP clone; excluded from DASP source control |

All language clients will be maintained in this repository. Each client will have its own package version and release process. Package names and the repository URL remain to be selected.
