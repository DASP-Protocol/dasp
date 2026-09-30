# Encrypted CloudEvent delivery

**Status: optional binding rules in draft-01. Exact setup and security evidence remain incomplete. [Issue #5](https://github.com/DASP-Protocol/dasp/issues/5) tracks this work. No complete binding interoperability is claimed.**

The encrypted binding uses the same CloudEvents envelope for plain and encrypted delivery. One `dasp.encrypted` carrier contains an encrypted original DASP CloudEvent. The binding decrypts it once, then passes the original message to normal core validation. Five core requests and fourteen core message types remain unchanged. The carrier is an additional binding wire type.

The requirements below apply when encrypted delivery is selected as part of a complete binding. Encryption is optional in the core and required on a connection that selects it. DASP remains unreleased; these rules add no protocol version. The design decisions below fix the minimum scope. Exact authenticated setup bytes, shared limit fields and values, health checks and deadlines, and independent security evidence remain [release requirements](#release-requirements).

## Reader boundary and selection {#dasp-enc-001}

Requirement group **DASP-ENC-001**.

### Accepted design decisions

| Topic | Minimum binding decision |
| --- | --- |
| Payload readers | The executing host authority and permitted clients can read payloads. Payload encryption protects contents from relays. Host storage needs separate protection. |
| New readers | Host policy grants access. A permitted reader receives all history needed for recovery, or the host refuses the attachment. Future-only access is outside this minimum contract. |
| Later reader-key compromise | The binding makes no promise that captured earlier payloads remain secret. Close affected connections and replace keys through trusted administration. |
| Key trust | Use configured trusted records for independent signing and reader keys. Messages cannot register their own keys. The administration method is a deployment concern. |
| Endpoint | Use a configured `wss://` address and trusted host keys. Automatic discovery is outside this minimum binding. |
| Selection | The client requests one exact contract and encryption suite. The host accepts or refuses it. Both peers confirm the same selected settings. Required encryption cannot fall back to plain delivery. |
| Limits and health | The binding defines shared fields, units, ranges, and failure behavior. The host selects permitted values. Local controls remain bounded. Binding health checks use no new core commands or periodic history polling. |

These decisions accept the design scope and its stated limits. They do not establish a complete handshake or tested security guarantees.

The host authority can read commands and saved history. Its validation, execution, and history services belong to that authority. A relay, including one that terminates TLS, cannot read the encrypted inner message under the selected trust and cryptographic assumptions. Each permitted client receives a separate encryption of output. Network encryption does not protect readable host storage from the host.

The binding MUST retain TLS. It MUST select the exact core, profile, binding contract, encrypted mode, suite, limits, host authority, and registered peer keys before session creation. A required feature that is unsupported MUST fail selection. Required encryption MUST NOT fall back to plain delivery.

The client MUST use the configured secure endpoint and trusted host keys. It MUST request one exact contract and the single suite defined below, with its required features and receive limits. The host MUST accept that contract or refuse setup. It MUST NOT replace the requested contract, choose another suite, or remove required encryption. The host MUST select concrete shared values within the contract's bounds and both peers' requirements. The client MUST confirm that exact selection or refuse setup. Setup failure or timeout MUST close the connection without a core reply or protected resource details. Endpoint discovery and key enrollment messages are outside this minimum binding.

Each peer MUST generate a fresh 32-byte connection challenge from its operating-system cryptographic random source. It MUST NOT reuse an old challenge or substitute the peer's challenge for its own. Both peers MUST authenticate the same selection and both challenges before application traffic. The setup transcript MUST bind the selected signing and reader key bytes and IDs for both roles, authority, principal/device identity, core, profile, binding, encrypted mode, suite, and limits. Setup MUST prove possession and confirmation of the selected keys as required by the complete binding. Key resolution MUST use trusted records, not a key supplied by the relay. A relay's TLS identity alone is insufficient proof of the host's identity.

### Required setup flow

| Phase | Required behavior |
| --- | --- |
| 1. Client request | Request the exact contract, suite, and required limits. Identify the registered client signing and reader keys and send the fresh client challenge. |
| 2. Host selection | Resolve the peer keys through trusted records, check their validity and permitted setup context, and return the fresh host challenge, selected host signing and reader key IDs, and exact selected settings. A registry match alone does not authenticate possession of a key. |
| 3. Mutual confirmation | Both peers prove possession of their selected signing and reader keys and authenticate the same setup transcript, including both challenges and the selected limits. Each peer verifies the other peer's proofs and confirmation. |
| 4. Core traffic | Only after setup succeeds, start encrypted record numbering at 1 in each direction. The client can then send `session.open` and use live delivery with saved replay. |

These are ordered phases, not message names or a requirement for one message per phase. A signature made with a signing key alone MUST NOT count as proof of possession of the reader key. Each peer MUST withhold core traffic until its verification and the binding's mutual-confirmation completion rule have succeeded.

**Exact setup remains unspecified.** The complete binding MUST supply closed message shapes, transcript bytes, signature and reader-key proof inputs, confirmation order and completion rules, pre-core framing, failure behavior, and timeouts. The record fields below are not a handshake. No session open, command, or other core operation is permitted before setup succeeds. Do not claim interoperability from these record rules alone.

The selected first WebSocket binding requires [live subscriptions and saved replay](websocket-live-delivery.md). Encrypted selection maps each logical core event in that contract to exactly one carrier. Apply request correlation, session routing, open confirmation, fixed-boundary replay, and resync to the authenticated decrypted event. The carrier has no outer `requestid` or `session_id`. Apply encrypted outer limits to the WebSocket message and core limits to the inner event. This selection changes no delivery state rule.

## Carrier and protected header {#dasp-enc-002}

Requirement group **DASP-ENC-002**.

After setup, each WebSocket text message MUST contain one structured CloudEvent. The encrypted form has exactly these six attributes:

```json
{
  "specversion": "1.0",
  "id": "delivery-42",
  "source": "urn:example:client:one",
  "type": "dasp.encrypted",
  "datacontenttype": "application/json",
  "data": {
    "protected": "<base64url of protected JSON bytes>",
    "enc": "<base64url of HPKE encapsulation>",
    "ciphertext": "<base64url of encrypted core event and tag>",
    "signature": "<base64url of Ed25519 signature>"
  }
}
```

This display uses placeholders. The [recorded shape examples](../../conformance/fixtures/encrypted-carriers.json) use synthetic bytes, not valid encryption or signatures. The [raw header vectors](../../conformance/fixtures/encrypted-header-vectors.json) test parsing and encoding only. The [carrier schema](../../specification/draft-01/bindings/encrypted-carrier.schema.json) is separate from the core schema.

`source` MUST identify the binding sender. Each new delivery MUST have a fresh outer `id` within its source. The outer identity is not a command ID, request ID, saved event identity, or applied cursor. The first carrier form permits no optional outer attributes. `data` has exactly the four byte fields shown.

Decode `protected` to bytes `B`, then parse its UTF-8 JSON as a closed object:

| Field | Meaning |
| --- | --- |
| `binding` | Exact immutable binding-contract URI selected during setup |
| `authority` | Stable host-authority URI selected during setup |
| `suite` | Exactly `HPKE-0-0020-0001-0003-Ed25519` |
| `sender_kid` | Registered sender signing-key ID |
| `recipient_kid` | Registered recipient reader-key ID |
| `client_challenge` | Current client's 32-byte setup challenge, encoded as base64url |
| `host_challenge` | Current host's 32-byte setup challenge, encoded as base64url |
| `direction` | `client-to-host` or `host-to-client` |
| `record` | Next connection record number in this direction |
| `envelope` | Exact decoded copies of outer `specversion`, `id`, `source`, `type`, and `datacontenttype` |

All values are strings except integer `record` and object `envelope`. The carrier and header MUST use UTF-8 JSON without a byte order mark. The receiver MUST reject unknown fields, duplicate decoded JSON keys, invalid UTF-8, and metadata that differs from the protected copy. It MUST NOT trust the outer metadata before authentication. Object key order does not matter when comparing outer string values. Verification uses the original protected bytes, not a parsed and serialized replacement.

The original JSON number token for `record` MUST match `[1-9][0-9]*`, with value at most `9007199254740991`. Validate that token and its exact range before conversion to a runtime number. Signs, leading zeros, fractions, and exponents are prohibited, including `1.0`, `1e0`, and a fraction that a parser rounds to an integer. JSON Schema's parsed integer check alone is insufficient.

Carrier context strings and all header strings MUST satisfy the [CloudEvents String restrictions](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md#type-system): no control characters U+0000–U+001F or U+007F–U+009F, Unicode noncharacters, or unpaired surrogates. Valid surrogate pairs and equivalent JSON escapes decode to the same value. Receivers MUST reject prohibited values rather than normalize or replace them. Key IDs, authority, and binding values MUST match the selected trusted context exactly, without case folding or URI normalization.

All four byte fields and both challenges MUST use canonical unpadded [base64url](https://www.rfc-editor.org/rfc/rfc4648.html#section-5). Reject padding, invalid alphabet, invalid lengths, and nonzero unused pad bits. JSON Schema checks shapes; exact decoded lengths, encoding, UTF-8 byte limits, and outer/header agreement require custom validation.

## Encryption, signatures, and record order {#dasp-enc-003}

Requirement group **DASP-ENC-003**.

Use the single selected suite: [HPKE](https://www.rfc-editor.org/rfc/rfc9180.html) Base mode `0`, DHKEM(X25519, HKDF-SHA256) `0x0020`, HKDF-SHA256 `0x0001`, and ChaCha20-Poly1305 `0x0003`. Use independent [Ed25519](https://www.rfc-editor.org/rfc/rfc8032.html) signing keys. Ed25519 signatures do not encrypt content. HPKE Base mode does not authenticate the sender by itself.

The sender MUST use a fresh HPKE encapsulation for each delivery, with an operating-system cryptographic random source. Use HPKE's single-shot `SealBase(pkR, info, AAD, plaintext)` and `OpenBase(E, skR, info, AAD, C)` with one encryption per context. The HPKE internal sequence starts at zero; the DASP connection record is a separate counter. The plaintext MUST be one complete structured core CloudEvent encoded as UTF-8 JSON without a byte order mark. Use the exact following inputs, where `||` means byte concatenation:

```text
info = UTF8("dasp encrypted record") || 0x00 || B
AAD = empty bytes
E = 32-byte HPKE encapsulation
C = HPKE ciphertext, including its 16-byte tag
S = Ed25519.Sign(sender_signing_private_key,
    UTF8("dasp encrypted record signature") || 0x00 ||
    uint32_be(byte_length(B)) || B || E || C)
```

`S` is 64 bytes. Each peer MUST use a maintained HPKE implementation rather than a local assembly of its primitives. The host signs output and the client signs requests. These are delivery signatures, not independent audit signatures on each saved event.

Record numbering MUST start at 1 in each direction after fresh setup. It MUST increase by 1 across all sessions on that connection, within the safe integer range. Senders MUST serialize numbering and release in wire order. Receivers MUST authenticate records in wire order. A peer that releases or consumes the maximum record MUST close before a further record in that direction; numbers cannot wrap.

The release boundary is the handoff of a complete carrier to the WebSocket/TLS output path where it can reach the peer or relay. Internal queueing or encryption is not release. The final output path MUST select an eligible queued event, apply attachment discard and current key/permission checks, assign the next record, construct its header and fresh encryption/signature, and serialize release. The final authorization check and handoff MUST be ordered with revocation. An uncertain or failed handoff MUST close the connection; it cannot justify number reuse or a later gap.

Disposable queue entries MUST NOT consume committed record numbers. If an implementation prepares numbered carriers before release, discarding one MUST cause all affected later unsent carriers to be rebuilt in final release order with fresh encapsulations, or cause connection close. A released carrier MUST NOT be changed. For example, after record 40, discarding queued session A output lets session B's next released output use 41 and A's resync use 42. It MUST NOT leave a missing 41 or release stopped-stream output to fill that gap. These rules apply to discarded progress as well as updates.

The receiver MUST bound input and decoded fields, reject invalid header encoding, compare the selected context and expected record, verify the signature, and authenticate HPKE decryption in that order. Resolve keys only from authenticated setup state. Do not pass plaintext to core handlers, logs, or errors before record authentication succeeds. Duplicate records, gaps, wrong connection context, invalid signatures, and decryption failures MUST close the connection without a protected error detail or core failure reply. Recovery uses fresh setup and the existing DASP recovery rules.

After those checks succeed, the receiver MUST consume the connection record exactly once, before core/profile validation or application discard. A failed inner request or cancelled reply does not roll that counter back. Connection record state and the saved applied cursor are separate.

| Result after record checks | Connection action |
| --- | --- |
| Outer format, header, selected context, record order, signature, or decryption is invalid | Close without consuming an unauthenticated record or sending a core reply |
| Authenticated plaintext has invalid UTF-8, invalid JSON, duplicate keys, a nested carrier, or no usable core message/request context | Consume the record, then close without inventing reply correlation |
| A parsed client request has usable core type and request ID but fails core/profile or permission checks | Consume the record; use the core failure or rejected-receipt rules; the next record remains usable if the connection stays open |
| A structurally valid direct reply belongs to a replay request cancelled by resync | Consume the record, then discard its application result, including a failure reply |
| A host reply or saved event is invalid after decryption | Consume the record, stop application/cursor advancement, and close |
| The inner event is valid and current | Consume the record, then apply normal core and delivery processing |

For example, an authenticated invalid-profile request at record 1 can receive an encrypted failure; the next client record is 2. A discarded cancelled reply likewise consumes its host-to-client number while changing no applied cursor.

For a cancelled reply, identify its authenticated inner type and request ID after core shape validation and before resource, profile, or application processing. No nested saved fact in that discarded reply is applied. A push's optional request ID has no correlation meaning and MUST NOT cause it to be discarded as a reply.

## Core validation and recovery {#dasp-enc-004}

Requirement group **DASP-ENC-004**.

The receiver MUST decrypt exactly one carrier. The result MUST be an existing core CloudEvent. A nested encrypted carrier is invalid. Apply normal core, profile, resource, and current-permission checks before admission or data release. A plain core event on a connection that requires encryption MUST be rejected. Core optional-extension rules apply to the decrypted event; they do not add optional carrier fields.

The host MUST compare command retries using decrypted semantic input under [DASP-CORE-002](recovery.md#dasp-core-002). Fresh ciphertext, delivery ID, record number, connection, or registered key MUST NOT create another admission for equal authorized intent. A new retry retains its command ID and semantic data and uses a new inner request ID. Changed intent conflicts under the existing rules.

The host MUST retain the original saved event identities and semantic data. Replay encrypts them for the currently permitted client without rewriting saved facts. A replay page contains its original nested events; do not encrypt each nested event separately. Apply the same carrier rule to requests, replies, live saved updates, progress, resync notices, and valid decoded-request failures.

A carrier record number never advances an applied cursor. Clients MUST save applied state and its cursor together. They MUST retain unresolved command IDs and semantic input in protected local storage for later retries. Progress remains temporary. Encryption does not establish admission, completion, or the outcome of an external effect.

## Keys, permission, and storage {#dasp-enc-005}

Requirement group **DASP-ENC-005**.

Trusted registration MUST bind a stable principal or host authority to separate signing and reader public keys. Register key ID, purpose, bytes, validity, and revocation state. A key ID MUST NOT be reassigned. A key supplied by a message cannot register itself. Key possession MUST NOT grant permission.

The first binding MUST resolve both peers' keys through configured trusted records before setup can succeed. The host registry and client host-key configuration need not use the same storage or administration method. The binding specifies required trusted inputs and the effects of validity, replacement, and revocation. It does not require an automatic enrollment service or a registry administration wire protocol.

Each client device MUST have separate keys. Output MUST be encrypted separately for each currently permitted client. New readers receive retained history only if host policy grants that access. Key replacement MUST use trusted administration, close affected connections, and complete fresh setup. A compromised previous key's signature alone cannot authorize its replacement.

A peer that knows or suspects a selected key is compromised MUST stop using that key and close affected connections. Trusted administration MUST revoke the affected registration before replacement. Any replacement MUST use trusted administration and fresh setup before further traffic. These actions cannot make previously released ciphertext secret again.

The minimum binding MUST grant all history needed for an authorized reader's recovery path or refuse the attachment. It MUST NOT silently filter inaccessible sequences, fabricate an applied cursor, or reset history. Future-only reader access needs an explicit initial state and access boundary outside this minimum contract. Permission policy also covers outcomes, views, and saved retry decisions, which can disclose earlier work.

Current permission and selected key validity/revocation MUST be checked at the release boundary for replies, replay pages, updates, progress, and resync, including prepared encrypted output. Read revocation for an attached session MUST close its connection under the live-delivery contract. Close reasons MUST contain no protected resource data or head. Revocation cannot recall earlier plaintext or ciphertext already released to a relay or network.

Host storage MUST preserve semantic input, admission, saved events, and outcomes for their required lifetime. Delivery ciphertext alone is insufficient. Network and storage keys have separate lifetimes. Losing storage keys cannot justify a new empty history under an existing identity. Routine logs, traces, and errors MUST NOT contain private keys or plaintext payloads.

This static-reader-key design makes no promise that old ciphertext remains secret after later compromise of the reader key, in either direction. Rotation does not protect previously recorded deliveries if their old reader key is later disclosed. Traffic timing and content length remain visible, as do outer source, delivery ID, binding, authority, suite, key IDs, challenges, direction, and record count. Stable metadata can link activity. See [HPKE's application limits](https://www.rfc-editor.org/rfc/rfc9180.html#section-9.7).

## Separate outer and inner limits {#dasp-enc-006}

Requirement group **DASP-ENC-006**.

The binding MUST advertise equal or tighter values before session creation. Shared values MUST form part of the authenticated selection. The complete binding MUST name each shared limit field and define its unit, range, direction or scope, and exceeded-limit behavior. The host selects concrete permitted values; the client MUST confirm them or refuse setup. Byte counts below use bytes, page bounds use entry counts, and operational deadlines MUST use an explicitly defined duration unit. No unspecified shared default may be inferred:

| Value | Maximum |
| --- | --- |
| Encoded outer CloudEvent | 1,410,000 UTF-8 bytes |
| Outer metadata serialized without `data` | 768 UTF-8 bytes |
| Decoded protected header `B` | 768 bytes |
| Decoded encapsulation `E` | Exactly 32 bytes |
| Decoded signature `S` | Exactly 64 bytes |
| Decoded ciphertext `C` | 1,048,592 bytes, including its 16-byte tag |
| Decrypted core event | 1,048,576 UTF-8 bytes |

The outer byte cap applies to the complete WebSocket text message, including whitespace and escape expansion, not to each transport frame. The receiver MUST enforce the cumulative bound while processing fragments, before reassembly can exceed it. Decoded bounds apply before cryptographic work. It MUST apply the [core limits](cloudevents.md#dasp-env-004) again after decryption, including individual saved-event, profile-string, nesting, collection, and page bounds. Base64 expansion in the carrier has its own outer limit; it does not increase an inner core limit.

This first encrypted form MUST disable WebSocket compression. Each implementation MUST set concrete local connection-rate, parser depth/work, fragment/work/deadline, decoded-buffer, and queued-byte limits. Local work controls need not be sent to the peer unless the binding makes them part of selection. They MUST remain bounded and follow the binding's refusal, resync, or close rules when exceeded. They cannot silently discard required saved facts. The complete binding MUST distinguish these local controls from shared receive, queue/buffer, and deadline values. The host MUST ensure required saved facts and at least one-event replay pages fit the selected inner and outer limits before admission or attachment confirmation. A tighter selection on reopen MUST fail if it cannot recover existing required facts; it cannot truncate or rewrite them. Oversized application output needs a profile-defined reference rather than truncation.

Setup MUST reject a selected context whose keys, identifiers, permitted delivery-ID policy, and maximum record width cannot fit the aggregate header and metadata bounds in both directions. Individual field maxima do not imply that every combination fits. A header that fits at record 1 must also fit with the selected maximum record's width. This feasibility check occurs before any core operation.

Both header and outer metadata are closed shapes. The header cap counts original `B`, including its whitespace and escapes. The outer metadata cap counts a reconstructed object without `data`, in order `specversion`, `id`, `source`, `type`, `datacontenttype`, with no whitespace. In that reconstruction, escape only double quote and reverse solidus with a reverse solidus; encode every other permitted Unicode scalar as UTF-8. This defines the count without requiring a JavaScript runtime. The actual incoming message has its separate raw bound. Original `B` remains the signature and HPKE input; reconstructed metadata is never substituted for it. Custom validation MUST check these bounds that JSON Schema cannot express.

The complete binding MUST define setup/request/idle deadlines and authenticated host health-check messages, with exact completion and timeout rules. After setup, health checks MUST use authenticated binding controls, remain bound to the current connection, and follow the binding's defined control framing. They MUST NOT add core commands, require periodic history polling, or advance an applied cursor. Control message shapes and their relationship to carrier record numbering remain complete-binding work; the core-event-only carrier above does not implicitly define a health-check format. A relay can answer WebSocket Ping/Pong while withholding host traffic; its Pong does not establish authenticated host progress. A missed selected host-health deadline MUST close the connection. Reconnection requires fresh setup and recovery from the saved applied cursor. A malicious relay can still delay, drop, or close traffic. Neither encryption nor bounded work guarantees availability.

## Command and recovery example

Client A submits `counter.add`, command ID `cmd-add-3`, with `amount: 3`. The host decrypts and validates it, saves one admission, and completes the addition. The receipt is lost. A reconnects through fresh setup with its current keys and retries the same intent with fresh delivery encryption and a new request ID. The host returns the original admission as a duplicate. Changing the amount under that command ID conflicts.

A requests replay after its last applied cursor. The host encrypts the page for A's current key. Client B can request its own page under its own key if current policy permits it. Both pages contain the same original saved facts. Each client keeps its own state and applied cursor. Key changes do not change the saved outcome or execute the command again.

## Release requirements

The accepted design scope covers host-readable execution and history, required recovery history or attachment refusal, the static reader-key compromise limit, configured endpoints and trusted records, exact contract selection, and the setup flow above. Reader grants and key administration remain deployment concerns within those rules.

These rules are part of the unreleased draft. Before a complete interoperable binding can be released, its specification and evidence must include:

1. A complete authenticated setup and key-confirmation contract with exact messages, transcript bytes, proof inputs, and completion and timeout rules.
2. Exact shared limit fields and values, authenticated health-check framing and record-order rules, and failure and recovery behavior. Verify that local controls cannot weaken required history or release rules.
3. Two independent cryptographic implementations and vectors, pinned implementation versions and key-import/negative-verification behavior, and independent expert security review of the complete binding. Include pure Ed25519 point/signature acceptance and HPKE X25519 invalid-key/all-zero-secret behavior; do not infer agreement from library names.
4. Executed runtime evidence for trusted setup, record order, release/revocation, retries, encrypted live delivery, replay, and failure recovery.

The schema and [artifact checks](../../conformance/running-checks.md) cover structure and encoding only. The [runtime cases](../../conformance/behavioral-cases.md#run-encryption-auth-encrypted-delivery-and-setup) remain unexecuted. A host that must not read commands and a ratchet protocol require separate scope decisions.
