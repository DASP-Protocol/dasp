# DASP extension contracts

**Status: draft-01, unreleased.** This document defines extension requirements. It does not define setup message bytes or a cryptographic handshake. Complete bindings must supply those parts and their conformance evidence.

## Optional support and required behavior {#dasp-ext-001}

Requirement group **DASP-EXT-001**.

A DASP extension adds a specified capability without changing the core message contract. An implementation MAY support an extension. Once peers select it, both peers MUST enforce it in its selected scope. A host policy requirement is also mandatory. “Optional” does not permit a peer to ignore a selected or required capability.

These terms have different meanings:

| Term | Meaning |
| --- | --- |
| CloudEvents extension attribute | Additional event metadata with a defined name, type, and value rules. |
| DASP extension contract | Versioned behavior, selection, scope, dependencies, and conformance requirements. It can use attributes, binding carriers, or existing messages. |
| Setup subprotocol | Versioned pre-confirmation behavior that a binding mapping carries outside core messages and extension selection. |
| Application profile | Domain commands, payloads, state, and completion rules. |
| Transport binding | Authentication, setup bytes, framing, routing, delivery, and connection behavior. |

CloudEvents permits extension metadata and defines its names, types, and format mappings. Its optional attributes can be ignored by consumers that do not support them. DASP requires confirmed support when application behavior depends on that metadata. This is a DASP requirement, not a new CloudEvents rule. See the [CloudEvents specification](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md#extension-context-attributes) and [JSON format](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md#2-attributes).

An extension MUST NOT change core shapes, command retry equality, saved event identity, update ordering, admission durability, or terminal outcome meaning. It MUST NOT turn a receipt into completion or permit a cursor to skip an unsupported saved fact. An extension can restrict new admission or protected delivery under its specified rules. Application commands and payloads still belong to profiles. A feature that needs different core semantics requires a new core contract.

## Identity, definition, and dependencies {#dasp-ext-002}

Requirement group **DASP-EXT-002**.

An extension's identity is an absolute URI plus a nonempty version string. Peers MUST compare both values exactly, without URI normalization, case folding, or a version-range assumption. An event attribute name or carrier type alone does not identify an extension version. Identifiers are not instructions to fetch a resource.

Every extension definition MUST publish:

1. Its identity, version, status, and immutable content reference.
2. Exact supported core, profile, and binding contracts, or explicit compatibility rules for them.
3. All required extension dependencies, with exact identities, versions, and scope rules. It MUST state when there are no such dependencies.
4. Supported scopes, affected operations, and closed selection settings with value, unit, limit, and validation rules. It MUST state which settings remain session requirements and which are fresh connection settings.
5. Attribute or carrier rules, processing order, permission checks, errors, and behavior when evidence is absent or invalid.
6. Saved records, retry behavior, replay behavior, reconnect behavior, and upgrade rules.
7. Positive and negative examples, runtime cases, and the limits of available evidence.

The immutable content reference MUST pin all normative sources, schemas, and dependency definitions. For this editable draft, use a full source commit with repository identity, or a SHA-256 digest of an immutable manifest containing the required files and their digests. A URI, `draft-01`, a branch name, or a package version alone is insufficient. The complete binding MUST define the content-reference fields and include them in authenticated selection.

The requested and selected extension sets MUST contain the full required dependency set. Each peer MUST validate that set before confirmation. Unsupported dependencies, conflicting attribute definitions, incompatible scopes, cycles in required dependencies, or conflicting settings MUST fail selection. Peers MUST NOT silently add, remove, or replace a dependency after confirmation. Configuration can supply the definitions; automatic discovery is not required.

## Scope {#dasp-ext-003}

Requirement group **DASP-EXT-003**.

| Scope | Required behavior |
| --- | --- |
| Connection | Enforce the extension on the specified traffic for the entire confirmed connection. Each new connection requires fresh selection and confirmation. |
| Session | Enforce the extension for the session's specified operations across connections, clients, and host restarts. Save its requirements with the session. |
| Command | Enforce the extension for the specified command names or exact targets. Save required evidence with admission under the extension's retry rules. |

A definition MAY have requirements in more than one scope. It MUST define their relationship. For example, connection encryption can establish a lasting session delivery requirement. Command authority can be selected for a session and checked on each new admission.

The binding MUST bind each selection to an unambiguous scope and profile. It MUST define how a connection with several sessions resolves their requirements. A connection-wide protection applies to all its core traffic. A session or command setting cannot disable it for one message. Incompatible session settings require separate connections or refusal.

Command scope MUST be selected before `session.open`. The agreed rules determine which later commands require evidence. A command cannot select its own required extension by adding an attribute. It cannot change the confirmed proof kind, trusted issuer policy, or protected delivery mode. A command-scoped extension MUST define equal-retry recovery separately from new admission. It MUST preserve the core retry identity.

## Authenticated selection and mutual confirmation {#dasp-ext-004}

Requirement group **DASP-EXT-004**.

Authentication and extension selection MUST complete before any `session.open` or other core operation. Both peers MUST authenticate the other peer and confirm the same exact selected contract. A configured endpoint, advertised feature list, registry match, or successful schema validation is not confirmation.

The optional [capability-discovery setup
subprotocol](capability-discovery.md#dasp-disc-001) can run before the client
knows the actor profile. The peers first select and authenticate its exact
binding mapping. Discovery can then reveal the actor's one profile descriptor.
After that step, the peers perform the normal exact core, profile, binding, and
extension selection described here. Discovery is not an extension. It cannot
select or confirm an extension and cannot weaken any saved protection
requirement.

The complete binding MUST authenticate all of the following as one selection:

- Peer roles, host authority, and client principal, with the binding's required key and connection context.
- Exact core, profile, and binding identities and their content references.
- Every selected extension's identity, version, content reference, scope, complete settings, and required dependencies.
- Shared limits, required capabilities, and any binding-specific freshness and key-confirmation inputs.

The client MUST request one exact contract and extension set that meets its own requirements. The host MUST check that request against its supported contracts and current policy. It MUST accept that exact contract or refuse it. It MUST NOT remove a selected extension, substitute a version, weaken evidence, or fall back to plaintext. The host selects only permitted shared values within the contract and both peers' declared requirements. The client MUST confirm those exact values or refuse setup. Both peers MUST withhold core traffic until their verification and the binding's mutual-confirmation completion rule succeed.

Host policy can require extensions for an authority, principal, profile, session, command, or protected resource. The client cannot remove those requirements. If a request omits a required extension or conflicts with policy, the host MUST refuse that selection. A complete binding MAY disclose permitted policy metadata so that a client can make a new acceptable request. It MUST NOT treat silence or timeout as consent. Neither peer may automatically retry with weaker requirements.

The complete binding MUST define setup framing, closed messages, authenticated transcript bytes, confirmation order, completion, freshness, timeouts, and refusal behavior. It MUST bind confirmation to the current connection and prevent reuse of an old confirmation. For encrypted delivery, [DASP-ENC-001](payload-encryption.md#dasp-enc-001) also requires the specified challenges and possession of both key purposes. This document supplies no replacement proof or partial handshake.

## Saved session protection and recovery {#dasp-ext-005}

Requirement group **DASP-EXT-005**.

Before the first successful `session.opened`, the host MUST save the session's extension requirements with its identity, actor, and profile. This record MUST include the exact contract identities and content references, persistent semantic settings, affected operations, dependency requirements, and required protection established by the selected connection. An encrypted connection MUST establish required encrypted delivery for sessions created on it. A selected authority contract MUST establish its command evidence rules for those sessions. These requirements are a protection floor for the session lifetime.

A protection floor is the least protection permitted for a session. It is independent of a connection's lifetime. Store these requirements under the same declared durability boundary as the session. Saving the session tuple without its requirements cannot establish a successful creation. A lost or unreadable requirement record cannot be treated as an empty set.

Before reopening a session, the host MUST check fresh authenticated selection against the saved floor and current policy. It MUST do so before returning `session.opened`, its cursor, or any protected output. The host MUST also enforce the floor on commands, direct reads, retries, replay, progress, resync, and live output. Omitting `session.open` cannot bypass it. A connection that does not meet the floor MUST receive no protected session data and MUST NOT admit new work for that session.

Each client MUST retain the required contract references and persistent settings with its session recovery records. On reconnect, it MUST require them before sending protected intent or accepting protected output. Another authorized reader must also meet the host's saved requirements; the original client's connection does not grant that reader an exception.

Fresh challenges, connection counters, current trusted delivery keys, and connection-local limits are not saved command intent. They can change only as the selected contracts permit. A tighter limit is acceptable only if it satisfies every saved requirement and permits complete recovery. Otherwise the host MUST refuse attachment. Required history cannot be filtered, truncated, or skipped to fit a weaker connection.

Current policy MAY impose stronger requirements. It MUST NOT weaken the saved floor. If no supported selection meets both, the host MUST refuse protected access. This draft defines no protocol to remove or migrate persistent extension requirements. An incompatible extension upgrade therefore requires continued support for the saved contract or refusal; a different version cannot silently replace it.

Equal authorized retries MUST keep their saved command identity and semantic input. They MUST NOT create a new admission because connection settings or authority evidence changed. Required extension enforcement still applies. Expired authority can use the authority contract's `recover` form with current independent recovery permission; it does not require a new valid grant or authorize new work. Encryption remains required if the session floor requires it.

## Enforcement and failure {#dasp-ext-006}

Requirement group **DASP-EXT-006**.

After selection, receivers MUST validate and enforce each selected extension before its affected action. Required missing, malformed, stripped, unsupported, or changed evidence MUST fail. A generic CloudEvents or core schema pass MUST NOT bypass that check. A receiver MUST NOT process the message as if the selected extension were absent.

Bindings MUST define pre-core selection failure and connection-close behavior. Failures after core decoding use the existing failure or rejected-receipt rules and the extension's stated error mapping. No new core error code is added here. Authorization masking takes precedence over details that could disclose protected resources. A refusal, timeout, or connection close does not cancel admitted work or establish a terminal outcome.

An unselected optional CloudEvents attribute retains [DASP-ENV-003](cloudevents.md#dasp-env-003) behavior. It supplies no evidence that a feature was selected or enforced. Host policy MUST prevent protected work from being admitted through an unselected contract.

CloudEvents extension names MUST use lowercase ASCII letters and digits. Definitions SHOULD keep names short and avoid collisions. An extension MUST NOT redefine a standard CloudEvents attribute or `requestid`. Attribute values MUST use the CloudEvents type system and its format mapping. In structured JSON, extension attributes are top-level members. Required feature settings belong in binding setup, not an object-valued CloudEvents `extensions` attribute. Confidential evidence needs the selected binding's protection; context metadata can be visible to intermediaries. See the [CloudEvents naming and type rules](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md#context-attributes).

Each definition MUST state whether an attribute is saved event data or delivery metadata. Required saved attributes MUST retain their original values on replay and be included in duplicate comparison. Delivery metadata can change only under its definition. Unsupported required saved semantics MUST stop application and cursor advancement. A carrier identity, evidence value, or extension version is never an applied cursor.

## Existing draft extensions {#dasp-ext-007}

Requirement group **DASP-EXT-007**.

These identities supplement the existing contracts. They add no field to core data, signed grants, or encrypted carriers.

| Contract | Identity and version | Scope and dependencies |
| --- | --- | --- |
| [Encrypted delivery](payload-encryption.md) | `https://dasp-protocol.github.io/dasp/contracts/encrypted-delivery`, version `draft-01` | Connection protection and saved session delivery requirement. Requires the exact selected core, profile, and first complete secure WebSocket binding with its live-delivery rules. No authority extension dependency. |
| [Proof of authority](proof-of-authority.md) | `https://dasp-protocol.github.io/dasp/contracts/proof-of-authority`, version `draft-01` | Saved session command rules, enforced at new command admission. Requires the exact selected core, profile, scope schema, and authenticated complete binding. No encrypted-delivery dependency; host policy can require both. |

These identities name editable draft definitions. Selection MUST also pin their content under DASP-EXT-002. The common identity and scope information MUST be bound to each extension's existing closed settings in the authenticated selection. A complete binding supplies that representation. The authority selection `contract` value remains its existing URI; its closed object does not acquire a version field.

`requestid` is a core-required CloudEvents attribute on requests and direct replies. It is not an optional DASP feature to negotiate. WebSocket live delivery is a binding contract, not a new CloudEvents attribute. Separate polling-only bindings remain valid core bindings; this draft encrypted form supplies no polling binding.

`dasp.encrypted` is an outer binding carrier type. It is not a CloudEvents extension attribute. It contains one encrypted original core CloudEvent. Its closed outer shape and protected header remain unchanged. Required encryption applies to every logical core event on that connection, including reads, failures, live output, and recovery.

`daspauthority` is a String attribute on an inner core command when authority is selected. It stays outside `data.input` and semantic retry equality. It is prohibited on other types in that selection and on the encrypted outer carrier. Authority does not grant read access. Selecting both contracts authenticates and decrypts delivery before authority validation, saved retry lookup, and new-admission grant checks in the existing defined order.

## Versions and conformance {#dasp-ext-008}

Requirement group **DASP-EXT-008**.

Extension versions are independent of CloudEvents `specversion`, the core namespace, profiles, bindings, and client package versions. Published version content MUST be immutable. A change to required settings, evidence, scope, permission, saved interpretation, or enforcement behavior requires a new extension version. An optional attribute addition alone is not proof of compatibility.

A definition MUST state compatibility with earlier versions. Peers still select one exact version; they MUST NOT infer support from a name, a major version, or attribute acceptance. Saved session requirements and saved event interpretation MUST survive upgrades. Unknown required saved behavior MUST stop recovery before cursor advancement.

A conformance result MUST identify the exact core, profile, binding, selected extensions, content pins, settings, dependencies, implementation versions, executed cases, skipped cases, and durability boundary. It MUST distinguish optional-attribute parsing from extension enforcement. General core conformance does not establish support for an extension.

Required cases include failed selection, changed confirmation, host policy, missing evidence, scope separation, dependency failure, concurrent clients, reconnect without protection, restart with missing requirement records, and saved-event compatibility. See the [runtime cases](../../conformance/behavioral-cases.md). They are specified but not executed. Existing carrier and authority artifact checks remain partial evidence. Exact setup, independent security review, cryptographic agreement, and runtime protection remain complete-binding work.
