# Proof of authority

**Status: optional binding contract in draft-01. Reusable standing authority is the design basis. Independent security evidence and host runtime tests remain incomplete. No complete binding interoperability is claimed.**

A principal signs one standing grant for a work scope and time window. Its authenticated agent can submit many commands under that grant. Each new admission records the grant used. Admission does not consume the whole grant. A command-count budget is optional. Equal retries add no grant use or budget charge.

This contract selects the required CloudEvents extension `daspauthority`. It carries full grant evidence outside profile input. A protected command remains an ordinary core CloudEvent, including inside [encrypted delivery](payload-encryption.md). Five core requests and fourteen core message types remain unchanged. No protocol version is added.

## Roles and trust {#dasp-auth-001}

Requirement group **DASP-AUTH-001**.

| Role | Meaning |
| --- | --- |
| Principal | Authority holder recognized by host policy; it can be a person, account, organization, or service. It signs the grant. |
| Agent | Authenticated submitting party named by the grant. It chooses commands within standing scope. |
| Host authority | Stable authority that controls permission, admission, retry records, outcomes, and saved history. |
| Actor | Logical application target from the saved session tuple. It is not a process or authenticated caller identity. |
| Reader | Party with current permission to receive output. Command authority does not grant read access. |

The host MUST authenticate the agent through trusted binding context. It MUST bind each issuer signing-key ID to immutable public bytes, issuer identity, signing purpose, validity, and current revocation state. It MUST also establish that the issuer can grant the requested work scope. Key possession, a key registry match, and a valid signature alone grant no access. Messages MUST NOT register their own keys. Key IDs MUST NOT be reassigned.

The grant's `agent` MUST equal the authenticated stable agent identity. Device and key replacement require trusted administration. They MUST NOT change a saved command's retry meaning. Further delegation, grant chains, grant references, discovery, enrollment messages, and grant-registration operations are outside this contract. A standing grant does not permit its agent to issue another grant.

The host MUST resolve actor and profile through its saved session tuple. Event `source`, session ID, key ID, and other caller-supplied identifiers do not establish authority. Effective permission is the intersection of current host policy, the verified grant, and profile rules. A principal signature does not prove human review. No separate agent signature on each command is required if the binding authenticates its complete contents.

Sender authentication, permission, confidentiality, admission, and completion remain separate. Delivery authentication proves a sender under trusted keys. The grant limits permitted new work. Encryption protects content for permitted readers. Saved admission establishes accepted intent. Only a saved terminal outcome under the profile's execution boundary establishes completion.

## Required selection and carriage {#dasp-auth-002}

Requirement group **DASP-AUTH-002**.

The authority contract identifier is `https://dasp-protocol.github.io/dasp/contracts/proof-of-authority`. It names this unreleased draft contract, not a network lookup or a new protocol version. Selection MUST pin its source/schema bytes as part of the exact binding contract. A URI alone does not pin this editable draft.

Before session creation, peers MUST authenticate and confirm the same closed selection object. Its shape is defined in the [authority schema](../../specification/draft-01/bindings/authority-grant.schema.json), definition `selection`:

```json
{
  "contract": "https://dasp-protocol.github.io/dasp/contracts/proof-of-authority",
  "profile": { "id": "urn:example:dasp:counter", "version": "1" },
  "scope_schema": "https://dasp-protocol.github.io/dasp/schemas/draft-01/examples/counter-authority.schema.json",
  "commands": [{ "name": "counter.add", "kind": "standing" }],
  "grant_bytes": 16384
}
```

`commands` has 1–64 entries with distinct command names. Each entry requires either `standing` or `command` evidence for new admission of that name. An unlisted command cannot acquire new admission through this selected contract. An authorized existing retry follows DASP-AUTH-005 before new-grant rules. The selected profile and locally pinned scope schema MUST match. Selection identifiers have the same byte and string restrictions as grant identifiers below; `scope_schema` is limited to 512 UTF-8 bytes. No schema URI authorizes a fetch.

The host MUST refuse unsupported contract, profile, scope schema, proof kind, or required limits. Selection MUST include this object in the binding's authenticated transcript. There is no fallback to ignored optional evidence or another proof kind. Current issuer trust and permission remain host policy, not client-selected trust roots. The selected scope schema MUST define closed rules for every listed command. An unimplemented rule cannot be ignored.

Host policy determines when proof is required. If it requires this contract for an action, a connection that did not select and enforce it MUST NOT admit that action. The host MUST refuse a selection that weakens its required proof kind. A client cannot bypass direct approval by selecting standing mode, or bypass all evidence by omitting authority selection. An existing saved retry can still use independently permitted recovery through a supported binding.

On this selected binding, every `dasp.v1.command` MUST have a string `daspauthority` context attribute. It has exactly one of these forms:

```text
base64url(B) + "." + base64url(S)    full signed grant
"recover"                          recover existing admission only
```

`B` and `S` are defined below. The literal `recover` MUST NOT authorize new admission. A missing, empty, non-string, or malformed extension is invalid. The extension MUST NOT occur on another core message type in this selection. Hosts MUST NOT echo it into receipts, saved updates, or replay pages.

Unknown optional extensions retain DASP-ENV-003 behavior outside this selection. Thus a client MUST NOT send protected work until required support is authenticated and confirmed. Structural acceptance by a generic core validator is not authority enforcement. A stripped extension MUST fail on the selected connection, including on retries.

| Carriage | Result |
| --- | --- |
| Required scalar extension — selected here | Fits existing CloudEvents extension rules. Stays outside `data.input`. Remains inside the encrypted core event. |
| Binding command wrapper | Requires another binding shape and an explicit change to the encrypted core-event-only plaintext rule. Not selected. |
| Evidence in profile input | Becomes complete retry input. Changed credentials would conflict under an admitted command ID. Not selected. |

## Closed grant shapes and work scope {#dasp-auth-003}

Requirement group **DASP-AUTH-003**.

All grant objects are closed. Every listed field is required except `max_admissions`, which is permitted only for standing grants. Both the authority schema and the selected profile scope schema MUST pass. Profile-defined objects are closed by that scope schema, not by an unrestricted policy language.

| Common field | Required value |
| --- | --- |
| `contract` | Exact selected authority-contract identifier |
| `kind` | `standing` or `command`, matching the selected rule for the new command |
| `grant_id` | DASP ID, unique within the stable issuer identity |
| `issuer`, `agent`, `authority` | Exact absolute identifiers, each at most 512 UTF-8 bytes; no normalization |
| `signing_key` | DASP ID resolving only through trusted issuer records |
| `not_before`, `expires_at` | Nonnegative safe-integer Unix seconds, with `not_before < expires_at` |

The `authority` is the sole host audience. Another authority with the same key is not that audience. An endpoint alias for the same authenticated authority does not change audience. Wildcards and audience arrays are invalid. Common identifier strings MUST satisfy CloudEvents String restrictions. Application strings in an exact target retain the profile's ordinary value rules.

A standing grant adds `scope` and MAY add positive safe-integer `max_admissions`:

```json
{
  "actor_id": "counter-main",
  "profile": { "id": "urn:example:dasp:counter", "version": "1" },
  "sessions": { "mode": "listed", "ids": ["session-counter", "session-counter-two"] },
  "commands": [{ "name": "counter.add", "input_scope": { "amount_min": 1, "amount_max": 100 } }]
}
```

`scope` has exactly `actor_id`, `profile`, `sessions`, and `commands`. The actor uses DASP ID rules. The exact profile uses the core Profile shape. Within grants and selection, its ID is limited to 512 UTF-8 bytes and its version to 128 UTF-8 bytes; both use CloudEvents String restrictions. These proof limits do not change the core Profile shape. Commands have distinct names and exactly `name` and `input_scope`, with 1–64 entries. A command's complete input MUST pass its ordinary profile schema and the selected scope rule. Scope never changes retry data.

The closed session alternatives are `{ "mode": "listed", "ids": [...] }`, with 1–64 distinct DASP IDs, and `{ "mode": "actor-profile" }`. Listed sessions must also match the actor and profile. The second form explicitly permits any present or future session with that exact actor and profile. Missing session scope is invalid. Neither form grants open or read permission.

This first concrete scope schema is [counter authority](../../specification/draft-01/examples/counter-authority.schema.json). It selects the existing counter profile and only `counter.add`. Its closed `input_scope` has integer `amount_min` and `amount_max`. Require `1 <= amount_min <= amount_max <= 1000000`; both limits are inclusive. The resource is the counter state in the named session, bound to the named actor/profile. There are no paths, secondary resources, or external effects in this rule.

Other profiles need a selected closed scope schema and enforcement rules before use. Those rules MUST cover resource selectors and every field that can change the permitted effect. A phrase such as "edit this project", a schema-valid object alone, or an unchecked file prefix cannot establish resource authority. Do not execute input before resolving that scope.

A `command` grant instead has `target`, with exactly `session_id`, `actor_id`, `profile`, `command_id`, `name`, and complete `input`. It has neither `scope` nor `max_admissions`. The target MUST equal the authenticated command and saved session tuple, using DASP semantic equality for input. This optional mode permits one exact command. It replaces standing evidence for a name selected as `command`; this first contract does not combine two grants. Current host policy still applies. Standing evidence MUST NOT satisfy a direct-grant requirement.

The same standing grant ID and original statement bytes can authorize many new command IDs. Renewed expiry, changed scope, changed key, or any other changed statement requires a new grant ID. The host MUST bind `(issuer, grant_id)` to the original statement bytes on first successful use. Different bytes under a known grant ID MUST reject new admission, even if their decoded meaning is equal. Rejection alone does not reserve the ID. This immutable evidence rule is separate from command retry equality.

## Exact proof bytes and limits {#dasp-auth-004}

Requirement group **DASP-AUTH-004**.

Use plain Ed25519 with a trusted 32-byte public key and a 64-byte signature. Do not use the prehash or context variants. [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032.html#section-5.1)

```text
B = original UTF-8 JSON bytes of the grant, without a byte order mark
M = UTF8("dasp proof of authority") || 0x00 || uint32_be(byte_length(B)) || B
S = Ed25519.Sign(issuer_private_key, M)
```

The text, zero byte, and four-byte unsigned big-endian length are literal. Verify exact `B`; never parse and serialize it again for verification. Retain `B` for audit. No canonical JSON member order is required. The statement binds issuer, agent, audience, scope or exact target, time window, and any budget. It excludes its signature and delivery metadata.

Both byte fields use canonical unpadded base64url. Reject padding, non-alphabet characters, nonzero unused bits, and wrong decoded lengths. There is exactly one dot separator. [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648.html#section-5)

| Limit | Exact rule |
| --- | --- |
| Selected `grant_bytes` | Integer 1–16384; counts original decoded `B`, including whitespace and escapes |
| Extension length | At most `ceil(4 * grant_bytes / 3) + 87` ASCII bytes: encoded grant, dot, and 86 signature characters |
| Default in the example | 16384 decoded grant bytes; at most 21933 extension bytes |
| Grant JSON | Container depth at most 20; at most 1024 members/items per container; no duplicate decoded keys |
| Grant numbers | Canonical decimal integer tokens, within the DASP safe-integer range before conversion; exact expression below |
| Scope collections | At most 64 session IDs and 64 distinct command names |
| Enclosed command | Existing core/profile byte, depth, collection, string, and integer limits still apply |

For clarity, the number-token regular expression is `^(0|-?[1-9][0-9]*)$`. Reject fractions, exponents, negative zero, leading zeros, non-finite values, and out-of-range tokens in `B`. This proof encoding restriction does not redefine core semantic equality. Exact-target input uses that encoding in the signed grant; compare its decoded value with ordinary valid core input.

Reject invalid UTF-8, a BOM, unpaired surrogates, trailing input, and unknown grant/scope fields. Decode bounds MUST be checked before allocation or signature work. Byte limits apply before and after decoding. JSON Schema does not establish original tokens, byte limits, duplicate-key rejection, signature acceptance, or scope enforcement.

The extension counts toward the original 1048576-byte core message limit, including JSON escape expansion on the wire. It does not increase that limit. Peers MUST refuse an infeasible selection; commands whose event plus evidence exceeds selected limits MUST be rejected. A reissued larger grant can require a smaller command. Clients retain semantic input for recovery; they MUST NOT change it to fit under an admitted ID.

## Admission, retries, and budgets {#dasp-auth-005}

Requirement group **DASP-AUTH-005**.

The host MUST apply this order. Internal lookups may support permission checks but MUST NOT disclose inaccessible records.

1. Authenticate and, if selected, decrypt delivery. Enforce raw bounds and core shape. Require the selected extension on commands and prohibit it on other message types. For full evidence, check canonical byte encoding and decoded lengths. Validate the ordinary profile and saved session tuple.
2. Establish current permission for the requested new submission or recovery of saved admission. Look up the command ID across the host authority. Authorize disclosure before returning any saved result.
3. If the ID is admitted, compare session ID, command name, and complete input under DASP-CORE-002. Different data conflicts. Equal data with current recovery permission returns the original admission sequence. Do not use the submitted grant for this decision, verify it as new authority, add a use, charge a budget, or replace original evidence. An expired/revoked grant, replacement grant, or `recover` can therefore accompany an authorized equal retry. A malformed carriage value still fails step 1. The duplicate receipt makes no claim about the attached grant's validity.
4. If the ID is not admitted, require current new-submission permission and full grant evidence. The literal `recover` MUST fail without admitting work. Validate the grant bytes, both schemas, trusted issuer/key/purpose, signature, authenticated agent, sole audience, selected kind, complete scope, profile preconditions, current status, valid time, and capacity.
5. In one recoverable decision, save command identity and full retry data, one `command.accepted` update, immutable grant evidence or its durable link, one command-use record, and any budget charge. Bind use by `(host authority, command_id)` to issuer, grant ID, session ID, and admission sequence. Only then may acceptance become visible or dispatch occur.
6. Serialize the decision with grant-byte identity, local permission/status revisions, budget state, and time checks. Recheck if state changes during verification. A verification before expiry cannot authorize admission at or after expiry. Recheck current disclosure permission at receipt release.

Every new command records one use of its grant. A standing grant is reusable until its time, scope, current permission, or optional budget prevents further admission. No implicit one-use or per-session budget is permitted.

If `max_admissions` is present, count distinct new admissions across all covered sessions under `(host authority, issuer, grant_id)`. The check and increment MUST be atomic with admission. Failure, cancellation, uncertainty, restart, and session removal MUST NOT refund or reset that count. It is an admission count, not a resource-cost budget. Absence means no grant-specific count limit; host capacity still applies.

All replicas under the authority MUST share these durable decisions. Concurrent equal submissions, including different valid grants, converge on one admission. Only the winning decision records a use and charges its grant. Concurrent different commands cannot exceed a shared budget. The direct-grant mode similarly links its one permitted command atomically. Rejected work reserves neither command ID nor grant ID/use/budget unit.

After restart, recover the complete decision before dispatch. Partial use/budget/admission state requires reconciliation, never repeat execution. A crash after commit but before receipt permits equal retry. A crash before commit consumes nothing. Core effect reconciliation still applies; unestablished effects produce immutable terminal `uncertain`. Proof of authority does not establish exactly-once external effects.

## Time, revocation, reads, and failures {#dasp-auth-006}

Requirement group **DASP-AUTH-006**.

For new admission, require `not_before <= host_time < expires_at` at the commit decision, with no implicit grace period. The first contract uses host-owned authoritative grant/key status and permission records. A declared complete local revoked-ID set can establish active status by absence. Missing, stale, or unreadable status cannot. The host MUST NOT follow a grant-supplied status URL. External status protocols need a separate freshness and ordering contract.

The host MUST order local revocation with admission and final output release. If trusted time or required current status cannot be established, new admission MUST fail as unavailable. Cached signature verification MUST NOT bypass current status, time, scope, holder, budget, or permission checks.

Grant expiry/revocation blocks new admissions under that grant. It MUST NOT erase an admission, change an outcome, consume another budget unit on retry, or cancel admitted work by itself. A profile can define a stricter execution precondition and its resulting outcome. Such a rule cannot turn an admitted command into a pre-admission rejection.

Open, recovery, views, replay, outcome reads, and live delivery require explicit current host permission independent of this submission grant. This first contract carries no grant on those other requests and grants no read right. Host policy MAY depend on a grant's status, but then expiry or revocation MUST stop that access. A reader receives required history or attachment is refused. Do not filter sequences or reset cursors.

Current authentication, recovery permission, and disclosure permission MUST still be established for equal retries after expiry or revocation. A saved grant cannot replace these checks. Revoked authentication keys require trusted replacement and fresh setup. Suspected compromise stops affected key use and connections.

Check queued replies, replay pages, updates, progress, and resync at final release. Revoked attached-session read permission MUST close the connection under the live contract. If current read permission is unavailable, release no protected output and close an affected live connection. No close reason may disclose a protected head or resource. Earlier released plaintext or ciphertext cannot be recalled.

| Condition | Result |
| --- | --- |
| Unsupported required selection | Refuse setup; no core traffic. Exact pre-core failure framing remains complete-binding work. |
| Missing/malformed extension, prohibited message type, invalid core | Correlated `failure` with `invalid_message` if usable authenticated request context exists; otherwise binding close/refusal. No admission. |
| New valid command with invalid grant syntax, schema, or scope encoding | Rejected receipt with `invalid_message`; no use or charge. |
| New valid command with missing authority (`recover`), bad signature, wrong issuer/agent/audience/kind/scope, changed known grant bytes, or expired/revoked authority | Rejected receipt with `not_found` and `retryable: false`; do not disclose private grant status. |
| Current required status/time/storage unavailable | Rejected receipt with `unavailable`, `retryable: true`, where disclosure is permitted. No admission/use/charge. |
| Exhausted grant budget or established capacity/size limit | Rejected receipt with `limit_exceeded`, `retryable: false`. Equal authorized retries remain possible. |
| Unlisted new command | Rejected receipt with `unsupported_command`, `retryable: false`. |
| Changed admitted command data | Protected rejected receipt with `conflict`, `retryable: false`. |
| Unauthorized retry/read | Common inaccessible-resource `not_found` result; no saved admission disclosure and no false pending state. Failed reads use `failure`. |

Authorization masking takes precedence over detailed errors when they would disclose protected records. Receipts retain existing core shapes. A failure or timeout does not establish an execution outcome. A retryable result never permits a new command ID for unresolved intent.

## Audit and encrypted delivery {#dasp-auth-007}

Requirement group **DASP-AUTH-007**.

Retain original signed grant bytes and signature, resolved issuer/agent/key evidence, full semantic command, scope result, verification time, current policy/status revisions, and budget decision with each admission. A durable link to shared immutable evidence is sufficient. Retain shared evidence for at least the lifetime of every referring session retry record. Ending one session cannot remove evidence or reset a budget used by another. Capacity exhaustion rejects new work rather than deleting required records.

The host's private audit record adds no field to the closed `command.accepted` payload. No new saved event or audit-read operation is defined. Protect evidence under storage and audit-access policy; private keys and grant contents do not belong in routine logs or errors. Evidence does not establish a trusted external timestamp, a human review, or completion.

In encrypted mode, `daspauthority` is an attribute of the inner `dasp.v1.command`. The complete event, including the extension, is encrypted. It is not an outer carrier or protected-header field. The existing plaintext remains exactly one core CloudEvent. Neither the encrypted carrier schema nor its core-event-only rule changes. Required extension validation follows successful record authentication/decryption.

An authenticated record consumes its connection number once even if grant validation rejects its command. Such rejection consumes no admission budget. Fresh ciphertext, request ID, connection, or trusted delivery key does not change semantic retry equality. Replays retain original saved facts and use current permitted reader keys. Principal grant keys and reader keys have separate purposes and lifetimes.

The executing host can read inputs and grant scope under the accepted encryption boundary. Relays need neither grant interpretation nor grant-verification keys. An authority grant does not repair incomplete encryption setup or establish health-check behavior. Existing live dispatch/recovery clients expect already authenticated core traffic; this contract adds no connection, encryption, or health-control implementation.

## Examples, checks, and release requirements {#dasp-auth-008}

Requirement group **DASP-AUTH-008**.

The [signed fixtures](../../conformance/fixtures/authority-grants.json) contain a reusable eight-hour counter grant, listed and actor/profile session scopes, an optional budget, and exact-command evidence. They include original bytes, signature input, and a test public key. These are public test values, not trusted deployment credentials.

One grant permits `command-add-1` with amount 3 and `command-add-2` with amount 4, across its permitted sessions. No new principal action is needed. Each admission has its own saved sequence and use record. Losing a receipt does not remove that admission. After expiry, equal retry with `daspauthority: "recover"` returns the original sequence if current recovery permission permits it. A new command then requires valid current authority. Changed data under an admitted command ID still conflicts.

The [artifact checks](../../conformance/running-checks.md) verify closed shapes, original-byte parsing, signatures with one Node crypto implementation, scope examples, and recorded admission/budget decisions. These checks are not a running host, concurrent store, or secure binding. [Runtime cases](../../conformance/behavioral-cases.md#run-authority-admission-atomic-admission-and-budgets) remain unexecuted.

Before interoperability or deployment claims, the complete binding MUST supply authenticated setup bytes that bind authority selection, key possession/confirmation, shared limits, health-control framing, and deadlines. The encrypted-delivery contract's setup and independent security requirements still apply. The authority contract additionally needs:

1. Independent Ed25519/strict-encoding implementations and shared positive/negative acceptance vectors, including noncanonical signatures and public points.
2. Executed concurrent admission, budget, crash recovery, revocation/release, and encrypted retry/live-delivery tests across host replicas.
3. Review of issuer administration, scope enforcement for each supported profile, time/status trust, and audit retention.

No grant-registration service, reference cache protocol, general policy language, additional core operation, or separate signature on every agent command is required by this contract.
