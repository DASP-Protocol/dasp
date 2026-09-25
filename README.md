# Durable Actor Session Protocol

DASP is an open, language-independent server protocol for controlling durable actors through shared sessions. It defines command admission, saved outcomes, ordered updates, and recovery using CloudEvents messages.

For agent builders connecting applications, tools, and automation to durable actors.

**Status: draft-01, a working review draft.** The core can change. Elixir and TypeScript clients are planned. No transport binding or production profile is released.

[Read the guide](https://dasp-protocol.github.io/dasp/guide/) · [Specification](https://dasp-protocol.github.io/dasp/specification/) · [Conformance](https://dasp-protocol.github.io/dasp/conformance/)

## What DASP defines

- A stable identity for commands and explicit admission decisions.
- Saved outcomes that distinguish completion, failure, cancellation, and uncertainty.
- Ordered session updates and recovery from a saved cursor.
- Shared sessions that more than one authorized client can use.
- Generic message shapes, with application data defined by profiles.

The core does not require chat, turns, a model provider, an actor runtime, or a storage engine. CloudEvents supplies the envelope; DASP supplies the session behavior.

## Find your path

| Purpose | Start here |
| --- | --- |
| Understand the protocol | [Guide](docs/guide/README.md) |
| Use DASP in a project | [Build guide](docs/build/README.md) |
| Implement the contract | [Specification](docs/specification/README.md) |
| Inspect test coverage | [Conformance suite](conformance/README.md) |
| Find schemas and examples | [Reference](docs/reference/README.md) |
| Propose a change | [Contributing](CONTRIBUTING.md) |

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
| `clients/` | Language client status and future implementations |
| `website/` | Site theme and public brand assets |
| `scripts/` | Validation, site generation, and release preparation |

Generated pages are not edited or committed. Research, local skills, and work notes belong outside this Git repository.

See [RELEASING.md](RELEASING.md) to prepare a versioned review bundle locally. Package versions, protocol versions, and CloudEvents versions have separate meanings.
