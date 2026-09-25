# DASP and other protocols {#why-dasp-faq}

A client submits a command, then loses its connection before the reply arrives. Did the actor accept the command? Can the client retry it? Can another client recover the result?

**DASP defines common rules for these questions** across languages and actor implementations.

*Working draft · [Implementation status](README.md#current-state)*

## Why another protocol?

DASP needs a contract for actors that keep their identity and work across client connections. That contract must cover saved command admission, retries, outcomes, and recovery together. The application defines its commands; chat and turns are optional.

The protocols below cover related needs. DASP specifies the actor and recovery rules that integrations would otherwise need to agree on separately.

## When do I need DASP?

Consider DASP when your application needs these properties together:

- **Persistent identity.** Clients return to the same actor and session after a disconnect.
- **Reliable retries.** A lost reply does not cause a second command admission.
- **Shared access.** Several authorized clients work with the same session.
- **Recoverable history.** Each client can read saved outcomes and apply the updates it missed.

For a single tool call or agent task, an existing protocol may meet your needs. Use the [command and recovery walkthrough](../build/walkthrough.md) to assess the fit. DASP does not guarantee exactly-once external effects.

## Why not A2A?

Agent2Agent (A2A) fits task exchange between agents. It supports long-running tasks, streaming, and reconnecting clients. Its [Send Message retry rules](https://a2a-protocol.org/latest/specification/#331-idempotency) make duplicate detection optional.

DASP [requires equal retries to share one saved admission](../specification/recovery.md#dasp-core-003). A client can retry after a lost reply using the same command ID and data. That guarantee is part of the actor session contract.

## Why not MCP?

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/specification/2026-07-28) connects AI applications to tools and context. Its [Tasks extension](https://tasks.extensions.modelcontextprotocol.io/specification/draft/tasks) includes durable task handles and polling that can resume after a restart.

DASP defines recovery across many commands in a shared actor session. Its [recovery rules](../specification/recovery.md#dasp-core-011) cover command retries, saved outcomes, and missed updates together. A durable tool task addresses part of that need.

## Why not ACP?

The [Agent Client Protocol (ACP)](https://agentclientprotocol.com/get-started/introduction) defines communication between code editors and coding agents. It is a direct fit for that interface.

DASP serves clients of durable actors, including agents, workflows, and device controllers. An [application profile](../specification/profiles-and-bindings.md) defines the commands and results for each use. This lets the same session contract serve an editor, operator console, or background service.

## Why not AHP?

The Agent Host Protocol (AHP) supports shared agent sessions. Its [reconnection rules](https://microsoft.github.io/agent-host-protocol/specification/lifecycle.html#reconnection) replay missed actions or return fresh snapshots when the replay buffer is exhausted.

DASP draft-01 [retains saved updates, outcomes, and retry records for the full session lifetime](../specification/recovery.md#dasp-core-012). Each client recovers from its own applied position. This preserves the saved history and requires storage that grows with the session. The actor's commands remain application-defined.

## Why not AG-UI?

The [Agent User Interaction Protocol (AG-UI)](https://docs.ag-ui.com/introduction) connects agent runtimes to user interfaces through events and shared state. It fits applications that need to present agent activity and accept user interaction.

DASP defines the host's saved facts and the client's recovery behavior. For example, a client must [save its applied update position with its application state](../specification/recovery.md#dasp-core-010). This also serves clients without a user interface.

## What does DASP add to CloudEvents? {#why-not-cloudevents-alone}

[CloudEvents](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) supplies the common event envelope: identity, source, type, and data. DASP uses that envelope for its messages.

DASP adds [application behavior requirements](../specification/recovery.md) for command admission, outcomes, ordering, and recovery. A valid CloudEvent identifies an event. The DASP rules establish when a command is saved and how a client recovers its result.

## Could an existing protocol be extended instead?

Yes. DASP's design choice is to keep actor recovery rules independent of a particular agent interaction model. A separate specification lets clients implement and test those rules across languages.

An extension or adapter could expose the same contract through another protocol. It would need to preserve command identity, authorization, outcomes, and replay, and document any limits.

## Can these protocols work together?

Yes, as separate interfaces in one system. An agent could accept an A2A task, call an MCP tool, and use a DASP session to control a durable actor.

This is a possible design. DASP has no released adapters. Start with the [build guide](../build/README.md) to review the host, client, and profile responsibilities.

---

*Comparisons reviewed on 25 September 2026. Protocols can change. [Suggest a correction](../project/feedback.md).*
