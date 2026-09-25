# S05 initialization decision

Status: Approved by the user on 2026-09-20: “new grammar approved”.
Coding v1 remains the default and the frozen bundle is unchanged.

## Approved scope

Keep the current WebSocket endpoint, Phoenix topic, and single join round trip.
Keep the exact legacy join `{"version":1,"profile":"coding"}`, its reply,
operation names, Signal schemas, and saved-data readability.

Add one closed, opt-in join offer:

```json
{
  "versions": [1],
  "profile": {"id": "coding", "versions": [1]},
  "required_features": ["seigyo.core/1"],
  "optional_features": ["seigyo.progress/1"]
}
```

Its success response has this closed shape:

```json
{
  "version": 1,
  "profile": {"id": "coding", "version": 1, "digest": "<64 lowercase hex characters>"},
  "features": ["seigyo.core/1", "seigyo.progress/1"],
  "limits": {"frame_bytes": 524288, "page_items": 100},
  "capabilities": {"<existing capability fields>": "<existing values>"}
}
```

The limits above illustrate the shape. Implementation uses the existing
canonical limits, with explicit byte and item units. It does not increase
them. Both version arrays have 1–8 distinct positive safe integers. Each
feature array has at most 32 distinct ASCII names of at most 64 bytes.
The whole offer is at most 8 KiB. Unknown fields fail. Select the highest
supported offered protocol and profile versions. Required unknown features
fail; unknown optional features are not selected. Every selected feature must
have been offered. Profile requirements remain mandatory independently of
optional live display features.

Use the existing bounded Failure shape for join errors. A missing common
version uses `unsupported_version`; unsupported profiles or required features
use `invalid_field` with `profile` or `required_features`. Pre-join calls fail
before dispatch. After an opt-in initialization succeeds,
a second join fails without replacing the channel. A legacy join followed by
an opt-in join also fails. Two legacy joins retain the existing Phoenix
replacement behavior for coding v1 compatibility.

Persist the static Profile ID, Profile version, contract digest, and required
saved features with each Session. The legacy form maps to the frozen coding
v1 contract. Authorize each access first, then reject readers that cannot
read the saved contract. Reconnect must not silently replace that contract.
Connection buffers and credentials are not persisted as Session requirements.

The production server continues to provide the coding Profile. Add a minimal
echo Profile only as an acceptance fixture. It proves generic Session,
Command, Update, Result, and recovery behavior without a Workspace. Profile
schemas remain closed and owned by their static descriptor. Unknown coding
operations fail for that fixture. This does not add Profile management.

Reserve owner-qualified feature names such as `seigyo.progress/1`. The initial
optional feature controls transient Progress only. No open metadata map,
arbitrary executable name, new transport, operation rename, or mutable saved
feature set is part of this decision.

## Approval scope

The user approved the opt-in offer and selection above. Preserve the complete
legacy coding v1 path. Commit the implementation, schemas, and conformance
cases together in S05.
