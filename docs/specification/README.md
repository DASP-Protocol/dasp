# Scope and versions

**Status: draft-01. Working review draft; not a released interoperability contract.**

Use this section to implement the contract. For an explanation with messages, start with [Follow a command](../build/walkthrough.md).

## Scope and authority

The model, envelope, message definitions, recovery rules, profile and binding requirements, and security/version rules are normative for this draft. The designated [JSON Schema](../../specification/draft-01/envelope.schema.json) defines structural constraints. Prose defines behavior and cross-message rules. Both must agree; a conflict is a specification defect.

Guides, diagrams, examples, and design questions are informative. A proposal does not add a core operation. Tests provide evidence only for the cases they execute; they cannot override a requirement.

The core requires no chat interface, actor runtime, storage engine, or programming language. Profiles provide application meaning. Bindings provide transport behavior. No production binding, profile, host, or DASP client is released.

## Conventions

Uppercase requirement terms, including MUST, MUST NOT, SHOULD, and MAY, use the meanings in BCP 14, [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119.html) and [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174.html). Lowercase words have their ordinary meanings.

Each normative section has a stable requirement or requirement-group ID. A group identifies all constraints in that section, including its field tables. The [coverage index](../../conformance/README.md) links those IDs to executed artifact checks and planned runtime cases. An ID alone does not imply that a runtime test exists.

## Layers

| Layer | Responsibility |
| --- | --- |
| CloudEvents 1.0 | Event identity, source, type, and metadata |
| DASP core | Sessions, commands, admission, updates, outcomes, views, and recovery |
| Application profile | Inputs, outputs, state, completion, concurrency, and domain rules |
| Transport binding | Selection, authentication, connection, routing, and delivery |
| Implementation | Runtime, storage, scheduling, and execution |

DASP uses [CloudEvents 1.0.2](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) and its [JSON event format](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md). The wire value of `specversion` is `"1.0"`. CloudEvents does not supply DASP's retry, ordering, or durability rules.

## Read the contract

1. [Model and lifecycle](model.md)
2. [CloudEvents envelope](cloudevents.md)
3. [Message shapes](messages.md)
4. [Admission and recovery](recovery.md)
5. [Profiles and bindings](profiles-and-bindings.md)
6. [Security and versions](security-and-versioning.md)

Then inspect the [counter example](example.md) and [conformance coverage](../../conformance/README.md). Use the source commit with `draft-01` when citing this evolving draft. See [release preparation](../project/releases.md) for fixed-artifact packaging.

## First WebSocket delivery contract

[WebSocket live delivery](websocket-live-delivery.md) defines subscriptions through session open, fixed-boundary replay, resync, and connection-close stop. It adds no core operation or field. The minimum binding uses a configured secure endpoint, trusted host identity, and one exact contract selection. Normal operation needs no periodic history polling. Automatic discovery is outside this scope. A complete production binding still needs exact authenticated setup, shared limit fields and values, health checks and deadlines, and runtime conformance evidence.

## Proposed binding work

[Encrypted CloudEvent delivery](payload-encryption.md) defines candidate carrier, key, and recovery rules for issue #5. It is separate from the active core contract. Its accepted design scope permits the executing host to read payloads, requires recovery history or attachment refusal, accepts the static reader-key compromise limit, and uses configured trusted keys and the defined setup phases. Exact setup, shared limits, health checks, and independent security evidence remain incomplete. The requirement index records artifact evidence and unexecuted runtime cases without claiming an accepted complete binding.

## Conformance

Read [what is tested](../../conformance/README.md), [run the checks](../../conformance/running-checks.md), and inspect the [runtime test cases](../../conformance/behavioral-cases.md). Passing the artifact suite alone does not establish host conformance.
