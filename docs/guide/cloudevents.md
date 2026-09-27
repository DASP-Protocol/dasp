# Why CloudEvents?

A message needs an identity, a source, a type, and data. DASP uses an existing standard for those parts.

[CloudEvents](https://cloudevents.io/) is an open, widely used specification for event messages. It is a CNCF graduated project, with SDKs across languages. Systems such as Azure Event Grid, Amazon EventBridge, and Knative support it.

## A common envelope

The **envelope** is the set of fields around the message data. Common fields let tools identify, route, and inspect events across systems. DASP can use that tooling without inventing another envelope.

CloudEvents does not require a cloud service. DASP clients and hosts can run locally.

## Read one message

This example asks a counter to add 3. Select the field groups to see which layer defines each part.

<CloudEventAnatomy />

| Layer | Responsibility |
| --- | --- |
| CloudEvents | Event identity, producer context, type, and data format |
| DASP | Session, command identity, admission, outcome, and recovery |
| Application profile | Command names, inputs, outputs, and completion rules |

`specversion: "1.0"` is the CloudEvents version. The `v1` in `dasp.v1.command` is the DASP event-type version. They are separate.

## What the envelope does not promise

A valid CloudEvent does not prove that a command was accepted or completed. It does not save history or make retries safe. Those are [DASP behavior requirements](../specification/recovery.md).

DASP also limits the values and shapes it accepts. A general CloudEvents library can help handle the envelope; it cannot replace DASP validation.

See the [CloudEvents envelope rules](../specification/cloudevents.md) for exact requirements, or [follow a command](../build/walkthrough.md) to see the envelope in use.
