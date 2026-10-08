# Security and compatibility

## Trust boundary {#dasp-sec-001}

Requirement group **DASP-SEC-001**.

The host MUST use trusted transport or application authentication context for authorization. CloudEvents `source`, `subject`, event ID, session ID, command ID, and `requestid` are untrusted input. None grants access.

The host MUST check current permission on open, submit, every read, replay, and live delivery. For capability discovery, it MUST perform a fresh disclosure check before every page, detail, resource, and release response. It MUST also enforce the session's [saved extension protection requirements](extensions.md#dasp-ext-005), including on direct requests without an open attachment. Permission revocation must stop later delivery; queued output must be checked before release. Retry records remain protected after revocation.

The [WebSocket delivery contract](websocket-live-delivery.md#dasp-ws-006) closes a connection when read permission for an attached session is revoked. It permits no protected session data or head in the close reason and no protected resync notice after revocation.

Unknown and inaccessible core resources SHOULD return the same `not_found`
result to avoid disclosure. Capability discovery uses its masked `unavailable`
failure for absent, inaccessible, undisclosed, forged, or foreign targets.
Bindings MUST protect credentials and message contents in transit. Deployments
define storage encryption, audit access, retention, and principal policy.

Receivers MUST enforce byte, depth, collection, and integer limits before execution. They MUST reject duplicate JSON keys before a parser discards them. Implementations MUST NOT create runtime atoms, classes, code, or filesystem paths from received names.

Schema URIs are identifiers, not instructions to fetch network resources. Validators SHOULD use locally pinned schemas. Hosts MUST NOT follow `source`, `dataschema`, or profile URIs supplied by a client to make unapproved network requests.

Discovery selectors, resolved views, start identities, snapshots,
continuations, capability identities, and resource identities are references.
They grant no authority. A received opaque identity MUST NOT become a network
location, file path, module name, or executable value.

Host and client discovery caches MUST be partitioned by endpoint, peer,
authenticated context, actor, actor profile tuple, discovery contract version,
resolved view, snapshot, and resource. They MUST be discarded after an
authenticated-context change, disclosure contraction, or integrity failure.

Discovered names, labels, descriptions, schema annotations, defaults,
examples, and profile metadata are untrusted text. A client MUST keep them
inert until the output context applies suitable validation and escaping.

## Independent versions {#dasp-sec-002}

Requirement group **DASP-SEC-002**.

| Identity | Meaning |
| --- | --- |
| CloudEvents `specversion: "1.0"` | Envelope standard |
| DASP draft-01 | Current editable design checkpoint |
| `dasp.v1.*` | Proposed core major-version namespace |
| Capability-discovery URI, version, and content pin | Optional pre-confirmation setup contract |
| Profile URI and version | Application contract |
| Binding name and version | Transport contract |
| Extension URI, version, and content pin | Selected capability contract |
| Client package version | Language implementation release |

The current `v1` names are draft names. Implementations MUST explicitly select `draft-01` and MUST NOT claim compatibility with a future release from that name alone.

A released contract must pin schema bytes, profile and binding definitions, limits, and positive and negative fixtures with a digest. A breaking data or behavior change requires a new core or profile version as appropriate.

Unknown optional CloudEvents attributes can be ignored. A selected DASP extension cannot. Unknown core data fields cannot. Adding a required field, a new enum value, or a saved update kind is not automatically compatible. Extension version and upgrade rules follow [DASP-EXT-008](extensions.md#dasp-ext-008). An extension cannot supply a breaking change to the core under its existing version.

A host MUST preserve the interpretation of saved events and command keys across upgrades. If an implementation cannot decode a saved event, it MUST fail before advancing a cursor. Data migration cannot silently replace saved identities, terminal outcomes, or retry meaning.
