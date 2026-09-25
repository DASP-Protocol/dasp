# Seigyo Protocol: Wire

## Wire, validation, and version rules

The [Signal schema catalog](signals.md#signal-schema-catalog) defines current and
draft type names, fields, and limits. The local WebSocket adapter uses Jido
CloudEvents JSON with the exact frame format in ADR 0019. It checks the
encoded frame limit before decode, decodes the envelope, checks
allowed attributes and source, then validates the Jido Code type and closed Zoi
`data` schema. It rejects unknown types, unknown fields, unsupported versions,
invalid UTF-8, and excess size before admission. It never accepts Erlang term
format from a remote caller. `source` is a type provenance hint, not caller
identity. A replayed Signal may have a new envelope ID.

The `jido.client.*` type prefix identifies the Seigyo Protocol. The fixed
`/jido/code/client` and `/jido/code/server` sources name the logical producer role.
Those values can coexist: CloudEvents `source` is not the type namespace and
is not evidence of caller identity. An adapter checks the expected source
for the message direction after it authenticates the connection. A client
cannot gain access by setting either field.

`specversion` describes CloudEvents. `data.version` and the `jido.client.v1.*`
Signal type namespace describe the Jido Code contract. They are separate values. A released v1 adapter
accepts only the exact v1 request types named in its capability manifest and
only with `data.version: 1`. The manifest also names each supported
`Update.event_type` and its closed payload schema version. It emits only the
named result types and Update variants in the selected profile and capability
set. Planned
catalog entries are unsupported until that manifest includes them. It does not
reinterpret a v2 payload as v1. An unknown Signal type or higher version gets
`unsupported_version` when the adapter can identify it safely; malformed
input gets `invalid_field`. New optional fields inside a v1 closed object
are breaking changes. A new profile activity type must use a new protocol
version or a capability that the client selected before delivery. A client
MUST NOT receive an unknown durable event that it cannot apply and then
advance its cursor past it.

Coding v1 selects version `1` and profile `coding` in the WebSocket join. The
join result gives the exact capability set used on that connection. Session
persistence stores protocol version `1` and profile `coding`. The closed v1
Update union defines the event schema selected by that version and profile. A
mismatch or an unsupported stored Update returns a stable failure before the
cursor advances; it never removes an event from the stream.

The current `Jido.Seigyo.validate/1` checks known type and data after an envelope
has been decoded. It does not enforce remote source, attribute, frame, or
caller rules. These are required adapter gates. All integer values on wire
must be exactly representable in common JSON clients. String keys remain
strings. No decoder can call `String.to_atom`, `binary_to_atom`, or unsafe
term decode on received values.

| ID | Remote proof requirement |
| --- | --- |
| SEIGYO-WIRE-002 | When a remote input Signal has the wrong source for its direction, the adapter shall reject it before admission. A source value shall never grant access. |
| SEIGYO-WIRE-003 | When the selected version, profile, or capability set cannot represent a saved event, the Server shall not skip its Session sequence or report a later replay cursor as applied. |
| SEIGYO-WIRE-004 | Before remote release, the endpoint shall publish its supported operations, Signal types, Update variants, profile capabilities, exact transport frames, and stable error mapping for each operation. |

## Caller identity, authorization, and limits

Before remote access, the adapter authenticates a caller from trusted
connection context. Server authorizes that caller for Session open, command
submit, each read, and each attach. A client supplied Session ID, Workspace
ID, Signal `source`, Channel topic, or transport path is not an identity or an
authorization grant. A retry of `SessionOpen` may return an existing Session
only to a caller with access to it. A denied read must not reveal whether a
private Session or command exists. The current coding profile saves one owner
and tests every call and watch with two principals. Durable sharing and role
changes are not current Seigyo Protocol features.

The adapter enforces the catalog's per-field and portable value limits, a
512 KiB JSON frame limit, and a 256 KiB encoded Updates page limit. It also
bounds per-connection buffers, attachment count, concurrent calls, and
request time. The exact connection quotas are a deployment policy; the first
remote proof must set finite values and test overflow. Output fields must be
redacted for the caller before encoding. In particular, remote Progress must
not expose provider reasoning, secrets, raw tool output, local absolute paths,
or credentials without an explicit profile policy. Error replies contain
stable codes and safe field names, not exceptions or internal records.

## Transport mapping

Coding v1 uses the Phoenix Channel WebSocket endpoint fixed by ADR 0019. The
independent release bundle must publish its exact topic, join, call, push, and
error fixtures and the capability manifest. HTTP is a possible later
transport and is not part of coding v1.

| Transport | Calls and reads | Live delivery |
| --- | --- | --- |
| Native Elixir | Validated mutation Signals call Server. Typed read arguments call the same Server facade and return Signals or stable errors. | Subscribe after authorization, replay from Store, and apply the same cursor rules. |
| WebSocket | A call frame has an operation name and transport request reference. Mutation payloads are Signals. Replies carry the same Signal results. | Attach is connection state. Push full Updates, optional Progress, and ResyncRequired. |

WebSocket reply status describes transport handling. The Signal error code
describes the protocol failure. Phoenix Channel topics and references stay in
the adapter. The Channel does not own command state.
LiveView must use the public Server contract. A native TUI or GPUI must not
use private Agent or Store calls to change shared state. The TUI and GPUI use
the shared WebSocket-only `jido_seigyo` API. The current WebSocket route
is implemented for local acceptance. HTTP routes do not exist today.

The first Phoenix adapter uses this route and operation map. A WebSocket call uses `op`,
`request_ref`, and, for a mutation, one complete Signal JSON map. For a
read, it uses typed arguments. A reply repeats the `request_ref` and
contains one result Signal. The request reference is nonblank, has no
control character, has at most 128 UTF-8 bytes, and is unique among active
calls on that connection. An attach control needs a Session ID and the
client's last applied cursor, but no Command ID. ADR
[0019](../adr/0019-client-websocket-wire.md) fixes the Phoenix version 2 frame
shape and reply behavior for these calls and controls. The coding WebSocket uses
`watch_updates` with a Session ID and `after_sequence`, and `watch_progress`
with a Session ID. Each current Update subscription has one in-flight Signal
and a bounded pending queue. Overflow pauses that Session subscription and
pushes `ResyncRequired`. The client replays after its last applied sequence
and calls `watch_updates` again before it accepts more live Updates. Complete
external authentication and deployment quotas are still open.

The full WebSocket operation list comes from the join capability manifest.
The audited current list is in the
[coding v1 baseline](coding-v1-baseline.md#operation-and-client-inventory).
