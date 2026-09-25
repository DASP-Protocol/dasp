# CloudEvents envelope

DASP draft-01 uses the CloudEvents 1.0 envelope and JSON structured event format. Where a transport has a content type, the structured message uses `application/cloudevents+json`. The enclosed application data uses `datacontenttype: "application/json"`.

The format follows [CloudEvents](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) and its [JSON format](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md). The following restrictions are DASP rules, not additional CloudEvents requirements.

## Attributes {#dasp-env-001}

Requirement group **DASP-ENV-001**.

| Attribute | DASP rule |
| --- | --- |
| `specversion` | Required. Exactly `"1.0"`; this is not the DASP version. |
| `id` | Required. Nonempty CloudEvents string. Identifies one event within its source. No UUID format is required. |
| `source` | Required. Absolute URI identifying the producer context. Not the destination or an authorization grant. |
| `type` | Required. One core event type from the message catalog. |
| `datacontenttype` | Required. Exactly `"application/json"`. |
| `data` | Required. JSON object matching the selected core shape. |
| `subject` | Optional. If present on a session message, exactly its session ID. Not a routing authority. |
| `time` | Optional. RFC 3339 occurrence time. Never an ordering cursor. |
| `dataschema` | Optional. Absolute URI for the complete `data` schema, not just the nested application payload. |
| `requestid` | DASP extension. Required on requests and their direct replies. A nonempty opaque ID for one request attempt. |

A command event records that a client issued intent. A read event records a read request. Their CloudEvents envelopes do not make these operations durable or exactly once.

The binding selects the destination and reply path. `source` MUST NOT be interpreted as a reply URL to call.

## Three identities {#dasp-env-002}

Requirement group **DASP-ENV-002**.

| Identity | Purpose |
| --- | --- |
| `(source, id)` | CloudEvents event identity |
| `command_id` | Durable command retry identity in one host authority |
| `requestid` | Correlation for one request attempt in a client connection or binding context |

A new retry attempt MAY have a new event ID and MUST have a new request ID. It MUST retain its command ID and semantic data. A transport redelivery of the same attempt preserves the original event and request IDs.

The host MUST preserve a saved update's original `source`, `id`, `type`, and `data` on replay. It MUST preserve any originally supplied occurrence time, subject, and schema URI. Delivery-specific tracing extensions MAY differ if their extension definition permits it. No extension can change command semantics.

Consumers MUST NOT use a transport reference, event ID, timestamp, or progress count as an applied update cursor.

## Extensions and portable data {#dasp-env-003}

Requirement group **DASP-ENV-003**.

CloudEvents attribute names use lowercase ASCII letters and digits. DASP's extension is `requestid`. Optional unknown extensions MUST NOT alter admission or execution; receivers ignore their meaning but validate their CloudEvents representation. Forwarders SHOULD preserve them. Any required extension must be negotiated before use.

Context attributes use the CloudEvents type system. In particular, context integers are signed 32-bit values. DASP keeps its larger sequence values inside `data`, not integer extension attributes.

Core `data` objects are closed. Unknown core fields are invalid. Profile payloads are validated against the selected profile. JSON object key order is irrelevant; array order and string content are significant. Duplicate JSON object keys, invalid UTF-8, and non-finite numbers MUST be rejected before schema validation.

Draft-01 uses JSON integers in the safe range −9,007,199,254,740,991 through 9,007,199,254,740,991. Fractions and larger exact quantities MUST use profile-defined strings. Payloads can otherwise contain objects, arrays, strings, booleans, and null. This is a DASP portability choice, not a CloudEvents limitation.

DASP does not accept `data_base64`, a JSON string containing a second encoded object, or a null `data` field. A CloudEvents message that is valid for another application can still be invalid for DASP.

## Baseline limits {#dasp-env-004}

Requirement group **DASP-ENV-004**.

A binding MUST advertise equal or tighter limits before session creation.

| Limit | Draft-01 maximum |
| --- | --- |
| Encoded single structured message, including update pages | 1,048,576 UTF-8 bytes |
| Individual saved update event | 65,536 UTF-8 bytes |
| One string in application data | 65,536 UTF-8 bytes |
| Container nesting in each profile payload, counting its root as level 1 | 16 |
| Members per object or items per array | 1,024 |
| Updates per page | 100 |

A host MUST ensure every admitted command's required saved facts can be represented within the negotiated limits. Oversized outputs need a profile-defined reference mechanism, not silent truncation. Limits apply after decompression as well as to encoded message input.
