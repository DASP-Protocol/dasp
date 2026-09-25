# Security and versions

## Trust boundary

The host MUST use trusted transport or application authentication context for authorization. CloudEvents `source`, `subject`, event ID, session ID, command ID, and `requestid` are untrusted input. None grants access.

The host MUST check current permission on open, submit, every read, replay, and live delivery. Permission revocation must stop later delivery; queued output must be checked before release. Retry records remain protected after revocation.

Unknown and inaccessible resources SHOULD return the same `not_found` result to avoid disclosure. Bindings MUST protect credentials and message contents in transit. Deployments define storage encryption, audit access, retention, and principal policy.

Receivers MUST enforce byte, depth, collection, and integer limits before execution. They MUST reject duplicate JSON keys before a parser discards them. Implementations MUST NOT create runtime atoms, classes, code, or filesystem paths from received names.

Schema URIs are identifiers, not instructions to fetch network resources. Validators SHOULD use locally pinned schemas. Hosts MUST NOT follow `source`, `dataschema`, or profile URIs supplied by a client to make unapproved network requests.

## Independent versions

| Identity | Meaning |
| --- | --- |
| CloudEvents `specversion: "1.0"` | Envelope standard |
| DASP draft-01 | Current editable design checkpoint |
| `dasp.*.v1` | Proposed core major-version namespace |
| Profile URI and version | Application contract |
| Binding name and version | Transport contract |
| Client package version | Language implementation release |

The current `v1` names are draft names. Implementations MUST explicitly select `draft-01` and MUST NOT claim compatibility with a future release from that name alone.

A released contract must pin schema bytes, profile and binding definitions, limits, and positive and negative fixtures with a digest. A breaking data or behavior change requires a new core or profile version as appropriate.

Unknown optional CloudEvents extensions can be ignored. Unknown core data fields cannot. Adding a required field, a new enum value, or a saved update kind is not automatically compatible.

A host MUST preserve the interpretation of saved events and command keys across upgrades. If an implementation cannot decode a saved event, it MUST fail before advancing a cursor. Data migration cannot silently replace saved identities, terminal outcomes, or retry meaning.
