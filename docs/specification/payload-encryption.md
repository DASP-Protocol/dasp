# Encrypted CloudEvent delivery

**Status: proposed binding rules for review in [issue #5](https://github.com/DASP-Protocol/dasp/issues/5). Not an accepted or complete interoperability contract.**

The proposed binding uses the same CloudEvents envelope for plain and encrypted delivery. One `dasp.encrypted` carrier contains an encrypted original DASP CloudEvent. The binding decrypts it once, then passes the original message to normal core validation. Five core requests and fourteen core message types remain unchanged. The carrier is an additional binding wire type.

The requirements below apply only if this proposal is accepted and selected as part of a complete binding. They do not make encryption a required core feature. DASP remains unreleased; this proposal adds no protocol version. Exact authenticated setup bytes, reader policy, and independent cryptographic vectors remain [review gates](#review-gates).

## Reader boundary and selection {#dasp-enc-001}

Requirement group **DASP-ENC-001**.

Under the proposed boundary, the host authority can read commands and saved history. Its validation, execution, and history services belong to that authority. A relay, including one that terminates TLS, cannot read the encrypted inner message. Each permitted client receives a separate encryption of output. Network encryption does not protect readable host storage from the host.

The binding MUST retain TLS. It MUST select the exact core, profile, binding contract, encrypted mode, suite, limits, host authority, and registered peer keys before session creation. A required feature that is unsupported MUST fail selection. Required encryption MUST NOT fall back to plain delivery.

Each peer MUST provide a fresh 32-byte random connection challenge. Both peers MUST authenticate the same selection and both challenges before application traffic. Setup MUST prove possession of the selected keys as required by the complete binding. A relay's TLS identity alone is insufficient proof of the host's identity.

**Setup remains unspecified.** The complete binding must supply exact messages, transcript bytes, key confirmation, signature inputs, failure behavior, and timeouts. The record fields below are not a handshake. No session open, command, or other core operation is permitted before setup succeeds. Do not claim interoperability from these record rules alone.

The selected first WebSocket binding requires live subscriptions and saved replay. [Issue #4](https://github.com/DASP-Protocol/dasp/issues/4) defines proposed delivery work. This proposal does not accept that issue's rules or define a second event-delivery mechanism.

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

This display uses placeholders. The [recorded shape examples](../../conformance/fixtures/encrypted-carriers.json) use synthetic bytes, not valid encryption or signatures. The [carrier schema](../../specification/draft-01/bindings/encrypted-carrier.schema.json) is separate from the core schema.

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

All values are strings except integer `record` and object `envelope`. The receiver MUST reject unknown fields, duplicate JSON keys, invalid UTF-8, and metadata that differs from the protected copy. It MUST NOT trust the outer metadata before authentication. Object key order does not matter when comparing outer string values. Verification uses the original protected bytes, not a parsed and serialized replacement.

All four byte fields and both challenges MUST use canonical unpadded [base64url](https://www.rfc-editor.org/rfc/rfc4648.html#section-5). Reject padding, invalid alphabet, invalid lengths, and nonzero unused pad bits. JSON Schema checks shapes; exact decoded lengths, encoding, UTF-8 byte limits, and outer/header agreement require custom validation.

## Encryption, signatures, and record order {#dasp-enc-003}

Requirement group **DASP-ENC-003**.

Use the single proposed suite: [HPKE](https://www.rfc-editor.org/rfc/rfc9180.html) Base mode `0`, DHKEM(X25519, HKDF-SHA256) `0x0020`, HKDF-SHA256 `0x0001`, and ChaCha20-Poly1305 `0x0003`. Use independent [Ed25519](https://www.rfc-editor.org/rfc/rfc8032.html) signing keys. Ed25519 signatures do not encrypt content. HPKE Base mode does not authenticate the sender by itself.

The sender MUST use a fresh HPKE encapsulation for each delivery, with an operating-system cryptographic random source. The plaintext MUST be one complete structured core CloudEvent encoded as UTF-8 JSON. Use the exact following inputs, where `||` means byte concatenation:

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

Record numbering MUST start at 1 in each direction after fresh setup. It MUST increase by 1 across all sessions on that connection, within the safe integer range. Senders MUST serialize numbering and release in wire order. Receivers MUST authenticate records in wire order. Close before number exhaustion.

The receiver MUST check bounds, selected context, expected peers, signature, and decryption before accepting a record. It MUST accept only the next record number and advance that number only after authentication succeeds. Duplicate records, gaps, wrong connection context, invalid signatures, and decryption failures MUST close the connection without a protected error detail. Recovery uses fresh setup and the existing DASP recovery rules.

## Core validation and recovery {#dasp-enc-004}

Requirement group **DASP-ENC-004**.

The receiver MUST decrypt exactly one carrier. The result MUST be an existing core CloudEvent. A nested encrypted carrier is invalid. Apply normal core, profile, resource, and current-permission checks before admission or data release. A plain core event on a connection that requires encryption MUST be rejected. Core optional-extension rules apply to the decrypted event; they do not add optional carrier fields.

The host MUST compare command retries using decrypted semantic input under [DASP-CORE-002](recovery.md#dasp-core-002). Fresh ciphertext, delivery ID, record number, connection, or registered key MUST NOT create another admission for equal authorized intent. A new retry retains its command ID and semantic data and uses a new inner request ID. Changed intent conflicts under the existing rules.

The host MUST retain the original saved event identities and semantic data. Replay encrypts them for the currently permitted client without rewriting saved facts. A replay page contains its original nested events; do not encrypt each nested event separately. Apply the same carrier rule to requests, replies, live saved updates, progress, resync notices, and valid decoded-request failures.

A carrier record number never advances an applied cursor. Clients MUST save applied state and its cursor together. They MUST retain unresolved command IDs and semantic input in protected local storage for later retries. Progress remains temporary. Encryption does not establish admission, completion, or the outcome of an external effect.

## Keys, permission, and storage {#dasp-enc-005}

Requirement group **DASP-ENC-005**.

Trusted registration MUST bind a stable principal or host authority to separate signing and reader public keys. Register key ID, purpose, bytes, validity, and revocation state. A key ID MUST NOT be reassigned. A key supplied by a message cannot register itself. Key possession MUST NOT grant permission.

Each client device MUST have separate keys. Output MUST be encrypted separately for each currently permitted client. New readers receive retained history only if host policy grants that access. Key replacement MUST use trusted administration, close affected connections, and complete fresh setup. A compromised previous key's signature alone cannot authorize its replacement.

Permission MUST be checked immediately before releasing replies or queued live output, including output already encrypted. Revocation MUST stop further protected delivery. Close reasons MUST contain no protected resource data or head. Revocation cannot recall earlier plaintext or ciphertext already released to a relay or network.

Host storage MUST preserve semantic input, admission, saved events, and outcomes for their required lifetime. Delivery ciphertext alone is insufficient. Network and storage keys have separate lifetimes. Losing storage keys cannot justify a new empty history under an existing identity. Routine logs, traces, and errors MUST NOT contain private keys or plaintext payloads.

This static-reader-key design makes no promise that old ciphertext remains secret after later compromise of the reader key. It does not hide traffic timing or content length. The outer source, delivery ID, key IDs, and connection challenges are visible. See [HPKE's application limits](https://www.rfc-editor.org/rfc/rfc9180.html#section-9.7).

## Separate outer and inner limits {#dasp-enc-006}

Requirement group **DASP-ENC-006**.

The binding MUST advertise equal or tighter values before session creation:

| Value | Proposed maximum |
| --- | --- |
| Encoded outer CloudEvent | 1,410,000 UTF-8 bytes |
| Outer metadata serialized without `data` | 768 UTF-8 bytes |
| Decoded protected header `B` | 768 bytes |
| Decoded encapsulation `E` | Exactly 32 bytes |
| Decoded signature `S` | Exactly 64 bytes |
| Decoded ciphertext `C` | 1,048,592 bytes, including its 16-byte tag |
| Decrypted core event | 1,048,576 UTF-8 bytes |

The receiver MUST reject an oversized frame before unbounded allocation and enforce decoded bounds before cryptographic work. It MUST apply the [core limits](cloudevents.md#dasp-env-004) again after decryption, including individual saved-event, profile-string, nesting, collection, and page bounds. Base64 expansion in the carrier has its own outer limit; it does not increase an inner core limit.

This first encrypted form MUST disable WebSocket compression. The binding MUST bound connection rates, decode work, and buffered bytes. The host MUST ensure required saved facts and replay pages fit the selected inner and outer limits before admission or release. Oversized application output needs a profile-defined reference rather than truncation.

Both header and outer metadata are closed shapes. Metadata byte counts use compact UTF-8 JSON, with JSON.stringify-compatible escaping and the exact field order shown in the carrier example. Signature checks still use the original `B` bytes. Equivalent visible attribute values can have a different incoming order or whitespace; the complete incoming frame has its own bound. Custom validation MUST check metadata and byte lengths that JSON Schema cannot express.

## Command and recovery example

Client A submits `counter.add`, command ID `cmd-add-3`, with `amount: 3`. The host decrypts and validates it, saves one admission, and completes the addition. The receipt is lost. A reconnects through fresh setup with its current keys and retries the same intent with fresh delivery encryption and a new request ID. The host returns the original admission as a duplicate. Changing the amount under that command ID conflicts.

A requests replay after its last applied cursor. The host encrypts the page for A's current key. Client B can request its own page under its own key if current policy permits it. Both pages contain the same original saved facts. Each client keeps its own state and applied cursor. Key changes do not change the saved outcome or execute the command again.

## Review gates

This proposal is not ready to merge as an interoperable binding until the issue records:

1. Approval of the host-readable command and history boundary.
2. The policy for newly authorized readers and retained history.
3. Acceptance of the stated limit after later reader-key compromise, or a revised design.
4. A complete authenticated setup and key-confirmation contract with exact bytes and timeouts.
5. Independent cryptographic vectors, pinned implementation choices, and security review of the complete binding.

The schema and [artifact checks](../../conformance/running-checks.md) cover structure and encoding only. The [runtime cases](../../conformance/behavioral-cases.md#run-encryption-auth-encrypted-delivery-and-setup) remain unexecuted. Full APH authorization, a host that must not read commands, and a ratchet protocol require separate scope decisions.
