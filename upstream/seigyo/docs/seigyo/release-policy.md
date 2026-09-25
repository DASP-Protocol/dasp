# Seigyo Protocol release and compatibility policy

## Supported baseline

The first named baseline is protocol `1`, profile `coding`, binding
`phoenix-channel-websocket`. Its immutable bundle is in the `jido_seigyo`
package at `priv/seigyo/coding-v1`. The baseline records the local contract at
source revision `43c3a9323ec71bc1c5c6814f047e98bea3e56b4c`.

Known consumers are the shared Elixir client, the independent acceptance
application, and the TUI and GPUI application dependencies. The browser UI uses
the server facade. No external release or external consumer is established by
this repository. This does not remove the obligation to preserve saved local
Sessions, Results, Updates, configurations, Attachments, and retry identities.
The package version `0.1.0-dev` is not a wire contract identifier.

## Requirements

| ID | Requirement |
| --- | --- |
| SEIGYO-RELEASE-001 | A released bundle MUST be immutable. Its contract identity MUST bind protocol, profile, binding, every listed normative path, and the exact bytes at that path. A source revision MUST be separate provenance. The digest MUST NOT depend on credentials, authenticated principals, deployment addresses, timestamps, or the digest file itself. |
| SEIGYO-RELEASE-002 | A bundle MUST include schemas, operation and control metadata, custom validation rules, positive and negative vectors, behavior requirements, and conformance case IDs. Generation MUST reproduce the same bytes. An independent checker MUST detect a changed, missing, or renamed normative file. |
| SEIGYO-RELEASE-003 | An internal refactor MUST preserve accepted and rejected wire values and saved-data meaning. An implementation correction MUST identify the existing requirement and have a failing boundary test. An incompatible change MUST have an approved version or explicit feature-selection decision before implementation. An optional field in a closed object is an incompatible change. |
| SEIGYO-RELEASE-004 | Support continues for the current coding v1 baseline during S01–S09. No removal date is set. A later release MUST list supported contracts and any deprecation date. Unsupported saved data MUST fail explicitly before dispatch or cursor advancement. Migration MUST preserve identity, order, outcome evidence, and retry records; it MUST be explicit, recoverable, and tested before use. |

## Digest algorithm

The algorithm name is `seigyo-sha256-file-index-v1`. For each named normative
file, compute SHA-256 over its exact bytes. Encode the hash as lowercase hex.
Record `path`, `bytes` (byte count), and `sha256`. Sort entries by path in ASCII
order. All paths and index values are ASCII. Paths are relative to the bundle.

Create an object with `algorithm`, `protocol`, `profile`, `binding`, and
`files`. Encode JSON with object keys in ascending ASCII order, no whitespace,
decimal integers, and no escaped ASCII except JSON syntax. Hash these UTF-8
bytes with SHA-256. Add its lowercase hex value as `digest` to `contract.json`.
The digest thus binds the file names, sizes, and byte hashes. `contract.json`
and `provenance.json` are not normative files. The latter records source
revision only. A changed source revision does not change the contract digest.

A digest is a content identifier. It is not authentication. Different digests
do not by themselves establish incompatible behavior. No digest field is
added to the live v1 join or any other closed wire value.

## Authority and scope

The frozen bundle is authoritative for this named baseline. The release policy
and coding baseline determine its scope: only advertised coding v1 operations,
Signals, and Update variants are supported. Draft profiles, Work graphs,
transports, and other proposed features in the documents are not promises.
Behavior requirements govern meaning. Schemas govern closed structural rules;
the custom refinements in `operations.json` govern rules that JSON Schema
alone cannot express. Vectors illustrate requirements; they are not exhaustive.

If a generated artifact conflicts with a requirement, report the defect and
publish a corrected bundle with a new digest. Do not edit an old bundle or
silently declare the conflict compatible. The mutable acceptance manifest
records executable coverage; its passing case names are not an independent
claim that a deployment has passed them.

The existing `submit` and `submit_turn` operations, namespace, and v1 join
remain supported. A wire rename, merged submission grammar, new profile, or
feature-selection grammar needs a separate compatibility decision. S03 must
first document their current differences. Profile management and alternate
transports remain outside this work.
