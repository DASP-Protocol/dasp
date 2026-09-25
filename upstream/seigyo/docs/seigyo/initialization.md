# Seigyo Protocol initialization

Status: Opt-in bootstrap approved on 2026-09-20. The compatibility decision is
in [initialization-decision.md](initialization-decision.md). The frozen coding
v1 bundle is unchanged. These rules apply to the new offer unless stated otherwise.

## SEIGYO-INIT-001 — One bounded offer and selection

Use the existing `client:v1` topic and `phx_join` frame. Initialization is one
round trip. The legacy payload `{"version":1,"profile":"coding"}` and its
capability reply remain unchanged. The Elixir client uses legacy initialization
unless the caller supplies `initialization: Jido.Seigyo.Initialization.offer()`.
`Client.selection/1` returns the selection for an opt-in connection, or `nil`
for a legacy connection.

The new offer has exactly `versions`, `profile`, `required_features`, and
`optional_features`. `profile` has exactly `id` and `versions`. Both version
lists contain 1–8 distinct positive safe JSON integers. A profile name has
1–64 ASCII bytes and matches `[a-z][a-z0-9_]*`. A feature list contains at most
32 distinct names. The lists cannot overlap. The compact JSON offer has an
8,192-byte limit. The enclosing WebSocket frame has its existing 524,288-byte
limit. Units are UTF-8 bytes, not characters.

The successful response has exactly `version`, `profile`, `features`, `limits`,
and `capabilities`. The selected profile has exactly `id`, `version`, and
`digest`. The digest is 64 lowercase hexadecimal characters. Select the highest
common implemented protocol version, then the highest common version of the
requested profile. This implementation supports protocol version 1.

The [bootstrap schemas](../../apps/jido_seigyo/priv/seigyo/initialization-v1/schemas.json)
are generated from `Initialization.schemas/0`. `x-seigyo-maxJsonBytes` bounds
the compact UTF-8 JSON representation. Schema validation alone does not prove
feature selection, descriptor identity, authorization, or saved readability.
Those rules below remain required. Unknown fields fail.

## SEIGYO-INIT-002 — Fail before work starts

No common protocol version returns Failure `unsupported_version` with field
`versions`. An unsupported profile or profile version returns `invalid_field`
with field `profile`. An unsupported required feature, or a missing mandatory
profile feature, returns `invalid_field` with field `required_features`.
Malformed offers return bounded Failure data. Do not copy the offered value
into an error. Oversized offers return `too_large` with field `initialization`.

An opt-in join failure uses `{"failure": <Failure Signal>}` inside the Phoenix
error response. It does not establish a channel. A valid later offer can succeed.
Legacy invalid joins keep `{"reason":"invalid_join"}`.

## SEIGYO-INIT-003 — Connection state

Ordinary calls before successful initialization cannot dispatch to an operation.
The Phoenix binding rejects calls with no joined channel. After an opt-in join
succeeds, any further join on that connection fails with `conflict` and field
`initialization`, without replacing the first channel. A legacy join followed
by an opt-in join also fails. Two legacy joins keep Phoenix's existing channel
replacement behavior. A new connection has no previous initialization state.

## SEIGYO-INIT-004 — Features and limits

Select only offered, supported features. Every client-required feature must be
selected. The profile's mandatory features must also have been offered and
selected. Ignore unknown optional features. Return selected names in ASCII
sort order. A feature is a complete versioned contract, not an alias.

`seigyo.core/1` is mandatory. It gives the profile its Session identity, request
correlation, durable Command retry identity, ordered saved Updates, normalized
Results, and replay rules. Its frame and Signal schemas remain profile-owned.
For coding v1, the frozen contract fixes content variants, error codes, event
variants, and replay guarantees. Initialization does not change their shapes.

`seigyo.progress/1` is optional for coding. It enables the existing closed,
bounded Progress Signal and `watch_progress` control. Progress is transient.
It cannot advance a saved cursor or establish completion. Without this feature,
the opt-in capability lists omit that control and Signal; the server rejects a
raw attempt with `invalid_field`, field `features`.

`limits` contains the effective positive safe integer caps. Core requires
`websocket_frame_bytes`, `signal_json_bytes`, `request_ref_bytes`,
`json_integer_max`, `page_items`, and `updates_page_json_bytes`. A profile can
also include the existing named coding limits for the operations it implements.
No effective limit exceeds the published maximum. Profiles without coding
resources do not need to advertise Attachment, Workspace, or patch limits.

## SEIGYO-INIT-005 — Static profiles and access

Profile descriptors are static server configuration. Duplicate `(id, version)`
pairs fail; a server cannot give one identity two meanings. Production provides
only `coding` version 1. Its digest names the frozen coding v1 bundle. The
`echo` profile exists only in acceptance fixtures. It has its own closed inputs,
output fields, text content, and retention rules. Its Session, Command, replay,
and Result flow requires no Workspace. It does not advertise coding operations.

Initialization selects the profile for subsequent Session opens on that
connection. Opening an existing Session must match its saved contract.
Capabilities describe support. They never grant access. Check resource access
on every call and attach. A private Session and a missing Session have the same
public failure. Only an authorized caller can learn that saved requirements
are incompatible. Existing rejected-Receipt delivery remains unchanged.

## SEIGYO-INIT-006 — Client checks

Before work starts, check the closed selection, offered versions and profile,
required features, unoffered features, digest syntax, and effective limits.
Check that capability profile/version match the selection. The bundled typed
client also checks that the selected coding contract is the frozen contract it
can decode. A compatible bootstrap version alone does not make an unknown
profile contract readable. Do not infer support from an implementation version.

## SEIGYO-INIT-007 — Saved requirements and reconnect

Save protocol version, profile ID/version/digest, and the fixed required saved
feature set with each Session. Do not save credentials, connection buffers,
optional live Progress selection, or transient limits as Session requirements.
Existing coding v1 records migrate to the frozen coding digest and
`["seigyo.core/1"]`. Session storage version 7 contains `protocol_contract`;
older supported portable records are still readable. The database migration
uses a fixed digest, independent of the application installed when it runs.

After authorization, every remote Session operation and attach checks that the
reader has the exact saved contract and every required feature. A mismatch in
protocol version fails with `unsupported_version`; a profile identity mismatch
fails with `conflict`, field `profile`; missing required features fail with
`invalid_field`, field `required_features`. Reconnect never overwrites the saved
contract. Results and Updates refer to that immutable Session identity. The
join selection plus the successful open establishes their profile provenance.

The requirement set has no live mutation operation. Changing it requires a
future saved transition and reader checks. Unknown durable data must fail
validation before any client cursor advances. Optional Progress does not make
an unknown durable event safe to skip.

## SEIGYO-INIT-008 — Extension ownership

Feature names use an owner-qualified lowercase ASCII name plus `/` and a
positive decimal version, for example `example.feature/1`. Names have at most
64 bytes. The `seigyo.*` owner is reserved for the features defined here. A
server descriptor cannot register an unassigned name in that namespace. There
are no per-connection aliases or open metadata bags.

Every future feature needs a closed schema, byte and item limits, saved or
transient authority, support status, and independent tests before advertisement.
Configured skills and plugins are server-owned configuration references. They
are separate from negotiated protocol features and from private Jido runtime
Plugins. Feature negotiation does not accept module names or executable state.
