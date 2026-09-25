# DASP core specification

**Status: draft-01. Not a released interoperability contract.**

DASP is a language-independent protocol for durable actor sessions. It uses CloudEvents for message envelopes and defines the meaning of commands, admission, saved facts, and recovery. It does not require a chat interface, a particular actor runtime, or a storage engine.

This draft is the active DASP design. The imported implementation is reference material, not the normative DASP wire contract. Existing clients are not automatically compatible with this draft.

The words MUST, MUST NOT, SHOULD, and MAY identify requirements within this draft. An implementation cannot claim released DASP conformance until a release fixes the core, profiles, bindings, and conformance suite.

## Layers

| Layer | Responsibility |
| --- | --- |
| CloudEvents 1.0 | Event identity, source, type, and metadata |
| DASP core | Sessions, command identity, admission, updates, outcomes, and recovery |
| Application profile | Command names, input schemas, state, output schemas, and completion scope |
| Transport binding | Connection setup, authentication, discovery, routing, reads, subscriptions, and delivery |
| Implementation | Runtime, storage, scheduling, and execution |

DASP uses the [CloudEvents 1.0.2 specification](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) and its [JSON event format](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md). The wire value of `specversion` is `"1.0"`. CloudEvents does not supply DASP's command, ordering, retry, or durability rules.

## Core model

An **actor** is a logical target that performs application work. Its identity does not name a process, machine, language object, or connection.

A **session** binds one actor identity to one application profile and one ordered history. Its identity and profile remain fixed for its lifetime. More than one authorized client MAY observe it. An actor MAY have more than one session. There is no order across sessions.

A **command** is durable intent with a stable command ID. A **receipt** reports whether the host saved admission. An **outcome** records what the host can establish about execution. These are separate facts.

An **update** is an immutable saved event in a session. A **view** is a coherent projection at a saved cursor. **Progress** is temporary information that clients MAY discard.

A **host authority** is the logical service that owns sessions, command retry records, and the update log. It can span multiple processes or machines. It MUST publish a stable authority identity through its binding.

## Required behavior

- Save admission and its retry record before reporting acceptance.
- Keep each command ID unique across sessions within one host authority.
- Publish saved updates in session order.
- Preserve saved facts and event identity during replay.
- Separate temporary progress from saved outcomes.
- Check current authorization on each operation, including retries.
- Preserve uncertainty when effects cannot be established.
- Keep application-specific inputs and outputs inside profile payloads.

The core has no turn, conversation, message role, model, workspace, tool, or attachment type. Profiles can define these concepts without changing core semantics.

## Read in order

1. [CloudEvents envelope](cloudevents.md)
2. [Generic message shapes](messages.md)
3. [Admission and recovery](recovery.md)
4. [Profiles and transport bindings](profiles-and-bindings.md)
5. [Security and versions](security-and-versioning.md)
6. [Worked example](example.md)

The [JSON Schema](../../specification/draft-01/envelope.schema.json) describes structural constraints. Prose defines behavior and cross-message rules. A schema pass alone does not prove conformance.

Source history and compatibility differences are recorded separately in the [source mapping](../design/seigyo-mapping.md).
