# Language clients

Choose the API that fits your application. Both clients use the same DASP messages and recovery rules.

| Client | Package | Runtime |
| --- | --- | --- |
| [Elixir](elixir/README.md) | `dasp_ex` | Elixir 1.18+, OTP 27+ |
| [TypeScript](typescript/README.md) | `@dasp-protocol/client` | Node.js 22+, ESM |

Both are experimental, version `0.1.0-draft.1`, for `draft-01`. No registry release or production binding is available. The project license is pending.

## What the packages handle

They construct requests, validate core messages, check reply identity, and apply ordered updates to checkpoints. They also route duplex traffic and recover live delivery through fixed-boundary replay, bounded buffering, resync, and reconnect actions. They reject malformed JSON and stop on gaps or changed duplicate events.

## What you supply

Supply an authenticated transport, profile validator, state reducer, and durable storage. The packages do not open a WebSocket or implement connection setup, payload encryption, grant verification, or host admission. Save state, cursor, and duplicate evidence together. Keep command IDs and inputs for retries.

A timeout leaves admission unresolved. The packages do not retry automatically or cancel accepted server work.

## Elixir

The [Elixir client](elixir/README.md) uses Jido Signal. Replies and callbacks use `%Jido.Signal{}`. This is a package dependency, not a DASP requirement.

## TypeScript

The [TypeScript client](typescript/README.md) includes type declarations and its schema. Transport calls receive an `AbortSignal`. Browser support is not claimed.

## Build and test

From the repository root:

```sh
npm run clients:test
npm run clients:package
```

The language guides list setup steps and recorded examples. These examples use local reply adapters; they do not start a host.

[Client CI](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml) produces review archives. Tests cover parsing, reply checks, deadlines, retry construction, checkpoint recovery, duplex dispatch, and the shared live-delivery cases. See [protocol capabilities](../docs/specification/capabilities.md) for how clients fit with encryption and authority. See [what is tested](../conformance/README.md) for host and transport gaps.
