# Durable Actor Session Protocol

DASP defines the contract between an actor host and its clients: commands, saved outcomes, and recovery across connections. Use it to connect an interface, tool, or test driver to the same durable actor session.

**Status: draft-01, a working review draft.** The core can change. Experimental Elixir and TypeScript client packages are available in this repository. No transport binding or production profile is released.

The [Elixir client](clients/elixir/README.md) is built on [Jido Signal](https://github.com/agentjido/jido_signal). This is an implementation dependency; the DASP specification and TypeScript client remain independent of Jido.

[Read the guide](https://dasp-protocol.github.io/dasp/guide/) · [Specification](https://dasp-protocol.github.io/dasp/specification/) · [Conformance](https://dasp-protocol.github.io/dasp/specification/conformance/)

## Start here

1. [How DASP works](docs/guide/README.md): five operations and the replies they produce.
2. [Follow a command](docs/build/walkthrough.md): inspect real message shapes, a lost receipt, and recovery.
3. [Add DASP to your project](docs/build/README.md): client, host, and profile responsibilities.

[Specification](docs/specification/README.md) · [Protocol comparisons](docs/guide/faq.md) · [Conformance](conformance/README.md)

## Work on this repository

Use Node.js 22 or later and npm.

```sh
npm ci
npm run check
npm run docs:dev
```

`npm run check` checks the draft artifacts, publication inputs, the site build, and internal site links. It does not test a host or prove runtime conformance. `npm run docs:preview` serves the production build.

## Repository structure

| Path | Contents |
| --- | --- |
| `docs/` | Authored guide, specification, and project documents |
| `specification/` | Language-neutral schemas and example events |
| `conformance/` | Shared fixtures, coverage, and behavioral case definitions |
| `clients/` | Elixir and TypeScript packages, tests, and usage guides |
| `website/` | Site theme and public brand assets |
| `scripts/` | Validation, site generation, and release preparation |

Generated pages are not edited or committed. Research, local skills, and work notes belong outside this Git repository.

See [RELEASING.md](RELEASING.md) to prepare a versioned review bundle locally. Package versions, protocol versions, and CloudEvents versions have separate meanings.
