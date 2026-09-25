# ADR 0020: Share one independent WebSocket client

Status: Accepted for the local client slice
Date: 2026-09-19

## Context

The TermUI and GPUI applications need the same connection, request, and
protocol behavior. If each interface owns this behavior, request correlation,
error handling, and reconnect rules can become different. The interfaces do
not exist yet, so this is an application boundary decision.

The acceptance suite also needs test independence. If its only driver uses the
same encode and decode implementation as the client under test, one matching
bug can make a false passing result.

## Decision

Add `jido_seigyo` as an umbrella application. It uses WebSocket only and
can run in a separate BEAM instance. Its required configuration is an endpoint
URL and access token. It does not use Server, Web, TUI, GPUI, MockLLM, or
application environment state.

The public API uses `open`, `submit_text`, `updates`, `history`, `view`,
`trace`, and `workspace_changes`. It hides Phoenix frames and Signal
envelopes. Public results are Zoi-validated client structs. TermUI and GPUI
depend on this app instead of implementing transport code.

Acceptance scenarios use this API as their result boundary. The harness can
seed a Workspace, control MockLLM, or stop a process, but a normal scenario
does not inspect files, Git, Store, ETS, Server, or MockLLM. History proves
multiple-turn state. Trace gives bounded execution evidence. WorkspaceChanges
gives the current bounded Git change set without a physical path.

The production client depends on Seigyo Signal types. This is intentional. Seigyo
owns the protocol contract, and the client must remain compatible with that
contract. The acceptance app uses the public production client for every
scenario. It does not own a second socket process or duplicate Signal and ID
builders. Exact malformed-envelope checks stay in the client and Web wire unit
tests because the public client does not permit malformed Signal injection.

Each acceptance test starts one `Jido.Code.Acceptance.Runtime` supervisor.
That supervisor owns all test resources and temporary client processes. It
starts the test stack in dependency order and stops it in reverse order. A
control process monitors required components and stops the full runtime after
an unexpected component exit. Scenarios can also stop a named component on
purpose to test public failure behavior.

The acceptance application does not start a shared runtime from an
application callback. A shared runtime would couple tests through tokens,
model scripts, state, and failures. ExUnit owns each runtime and completes its
cleanup. The Web application owns only the stable client access registry.

Bounded waits use one monotonic deadline. Each request timeout is less than
the remaining wait time. Polling uses deterministic backoff and returns the
last observed result when the deadline expires. It does not use fixed
`Process.sleep/1` calls.

## Limits

This slice supports the current call and read operations. It does not define
live attach, reconnect and replay, token refresh, Progress push handling, or
Session close and cancel operations. The local token endpoint is not approved
for remote release.

## Consequences

TermUI, GPUI, and the acceptance suite share one tested client API. The client
remains usable without the Jido Code server source tree at runtime. Acceptance
tests now verify product behavior through the same API that native interfaces
will use. Wire adapter unit tests give focused coverage for malformed messages
that the public API cannot create. Isolated per-test runtimes permit parallel
scenario execution and controlled process-failure tests.
