# ADR 0019: Fix the first client WebSocket call format

Status: Accepted for the local coding v1 WebSocket profile
Date: 2026-09-19

## Context

The Seigyo Protocol defines operation meaning, but a non-Elixir client also
needs exact WebSocket frames. The first acceptance test must use a real network
connection. It must not use `Phoenix.ChannelTest` as its client surface.

The model test fixture already uses `Jido.AI.Test.MockLLM`. MockLLM provides
HTTP and SSE to Jido AI. It is not the Jido Code client endpoint.

## Decision

`jido_code_web` owns a Phoenix socket at `/client/socket`. The WebSocket URL is:

```text
/client/socket/websocket?vsn=2.0.0&token=<token>
```

The adapter accepts Phoenix version 2 JSON frames. It sets a 512 KiB WebSocket
frame limit. The first topic is `client:v1`. A client joins it with this
payload:

```json
{"version":1,"profile":"coding"}
```

The join reply names version 1, the coding profile, the authenticated
principal, supported call operations and controls, request, result, and push
Signal types, and durable Update variants. `Jido.Seigyo.capabilities/1` owns
the current list; the Channel does not keep a second list.

Each call uses the Phoenix event `call`. A mutation payload has exactly these
fields:

```json
{"op":"open","request_ref":"request-1","signal":{}}
```

`submit` has the same shape. A read has exactly these fields:

```json
{"op":"view","request_ref":"request-2","args":{}}
```

The transport reference is a nonempty UTF-8 string. It has no control
character and has at most 128 bytes. A successful Phoenix reply uses transport
status `ok` and this response:

```json
{"request_ref":"request-1","result":{}}
```

`result` is one complete server Signal. A failed Phoenix reply uses transport
status `error` and this response:

```json
{"request_ref":"request-1","failure":{}}
```

`failure` is one `jido.client.v1.failure` Signal. A transport status does not
replace the Signal error code.

Every Signal envelope has exactly `specversion`, `id`, `source`, `type`, and
`data`. Input accepts CloudEvents `specversion` `1.0`, a lowercase UUID version
7 ID, and source `/jido/code/client`. Output uses source
`/jido/code/server`. Unknown envelope fields and unknown nested data fields
fail validation.

The WebSocket token is trusted connection context. The socket does not use a
Signal source, topic, Session ID, or Workspace ID as caller identity. No token
is valid by default. The acceptance fixture installs one temporary token and
an isolated Server coordinator. The Web application supervises a local client
access registry. A test runtime registers its token with that registry. The
registry monitors the runtime owner and removes the token when the owner
stops. This avoids global application-environment changes between tests.

The development-only `jido_code_acceptance` app owns scenario data, the
MockLLM runtime fixture, and scenario tests. ADR 0020 replaces its first raw
WebSocket driver with the shared production client. It does not own production
protocol types, transport code, or server behavior. Its path is:

```text
scenario -> Jido.Seigyo.Client -> WebSocket -> Web -> Server -> Jido AI -> MockLLM
```

Client result assertions use the public client API. Focused client and Web
wire tests cover malformed frames that this API cannot create. A fixture can
inspect the mock or runtime after scenario assertions.

## Limits

This decision now fixes calls, capability discovery, live Update and Progress
controls, and ResyncRequired delivery for the local coding v1 profile. The
socket remains a local authenticated surface. External authentication,
deployment token storage, and exact connection quotas are not complete. The
repository has a generated machine-readable bundle and a raw WebSocket
black-box verifier. HTTP is future work and is not part of coding v1.

The in-repository acceptance manifest names the passing slices. It includes
disconnect replay for all ten advertised Update variants. Generated Signal
schemas and exact frame fixtures are checked for drift from the executable
catalog.

## Consequences

The test passes through the production socket and Channel serializer. It can
find errors that a BEAM-only Channel test cannot find. A future transport can
reuse common scenario data and assertions, but it must have its own adapter
proof.
