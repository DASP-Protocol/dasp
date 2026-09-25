# Language clients

Elixir and TypeScript have **experimental client packages for draft-01**. Both implement the same core messages, reply checks, and replay rules. They use transport adapters. No registry package, production binding, or host interoperability claim is released.

| Language | Package | Version | Runtime |
| --- | --- | --- | --- |
| Elixir | `dasp_client` | `0.1.0-draft.1` | Elixir 1.18 or later |
| TypeScript | `@dasp-protocol/client` | `0.1.0-draft.1` | Node.js 22 or later; ESM |

The project license is pending. These archives are for review. npm publishing is disabled with `private: true`. Hex builds report the missing license. Do not publish either package until the license and release process are approved.

## What the clients do

- Encode and decode all 14 core CloudEvents types with the pinned draft schema.
- Reject duplicate JSON keys, invalid UTF-8, unsafe numbers, invalid shapes, and baseline limit violations.
- Open sessions, submit commands, and read views, updates, and outcomes.
- Check reply IDs, message types, session identity, actor identity, profile, and producer context.
- Check replay page bounds and update order.
- Apply updates to a new checkpoint. Stop on gaps, changed duplicates, or missing duplicate evidence.

A receipt reports admission. It does not report completion. A timeout does not prove rejection. Save command identity and input before submission, then reuse them for each retry. Each client call creates a new request ID.

## Elixir

See the [Elixir package guide](elixir/README.md) for installation, API calls, errors, and recovery. Messages use maps with string keys. The package does not create atoms from message fields.

The transport callback runs in a monitored worker. A deadline stops that worker. It does not cancel admitted server work.

## TypeScript

See the [TypeScript package guide](typescript/README.md) for installation, API calls, errors, and recovery. The package includes generated type declarations and its schema.

The transport callback receives an `AbortSignal`. It must stop local I/O when the signal is aborted. A client deadline does not cancel admitted server work.

## What your application supplies

Supply an authenticated transport and a profile validator. The adapter must select the core, profile, and binding before use. It must set endpoints, credentials, framing, tighter negotiated limits, and any live subscription handoff. A CloudEvents `source` is a producer identifier, not a destination or an access grant.

Supply a pure state reducer and durable storage. Save the resulting state, cursor, and duplicate evidence in one transaction. The packages do not save data automatically. Keep one checkpoint per client and session. After a process restart, load that checkpoint, reopen the session, resolve saved commands, and request updates after its cursor.

## Build and test

From the repository root:

```sh
npm ci
npm --prefix clients/typescript ci
cd clients/elixir
mix deps.get
cd ../..
npm run clients:test
npm run clients:package
```

The package check installs both archives outside the repository and runs their recorded examples. Archives and a checksum manifest are written to `dist/client-packages/`. The examples do not start a server.

GitHub [Clients CI](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml) runs Node.js 22 and 24, Elixir 1.18 / OTP 27, and Elixir 1.20 / OTP 29. Its `client-packages` artifact contains the review archives. Dependabot checks npm, Mix, and GitHub Actions each week. Dependency pull requests run the same checks.

The tests execute client parsing, correlation, timeout, retry, and recovery code. They reuse the shared draft vectors. They do not establish host durability, storage atomicity, power-loss safety, authorization, or live transport interoperability. See [conformance coverage](../conformance/README.md).
