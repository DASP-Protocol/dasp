# DASP and other protocols {#why-dasp-faq}

DASP addresses the boundary between an actor host and its clients. These protocols cover related boundaries. Start with the job you need to do.

| Your need | Read |
| --- | --- |
| Exchange tasks between agents | [A2A](#why-not-a2a) |
| Connect an editor to a coding agent | [ACP](#why-not-acp) |
| Connect tools and context | [MCP](#why-not-mcp) |
| Share agent sessions | [AHP](#why-not-ahp) |
| Present agent activity in an interface | [AG-UI](#why-not-ag-ui) |
| Store and replay stream data | [Durable Streams](#what-about-durable-streams) |
| Use a common event envelope | [CloudEvents](#why-not-cloudevents-alone) |

## Why another protocol?

Clients need to agree on what acceptance, retry, and completion mean. DASP puts those rules in a shared actor-session contract. Commands remain application-defined; chat and turns are optional.

For one tool call or agent task, another protocol may fit. [Follow a command](../build/walkthrough.md) to assess what DASP adds. See [current status](../project/feedback.md) before planning an integration.

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

## What about Durable Streams?

[Durable Streams](https://github.com/durable-streams/durable-streams/blob/main/PROTOCOL.md) defines HTTP operations for saved, ordered stream data. It supports replay and live reads. Its producer rules address duplicate writes.

DASP defines command admission and saved outcomes, including uncertainty after owner loss. A stored message alone does not establish whether an actor completed its work.

A DASP binding could use Durable Streams to carry saved updates. The host would still need to enforce DASP admission, outcome, and retention rules. This is a possible design; no adapter is released.

## What does DASP add to CloudEvents? {#why-not-cloudevents-alone}

[CloudEvents](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md) supplies the common event envelope: identity, source, type, and data. DASP uses that envelope for its messages.

Read [Why CloudEvents?](cloudevents.md) for an annotated message. DASP adds [application behavior requirements](../specification/recovery.md) for command admission, outcomes, ordering, and recovery. A valid CloudEvent identifies an event. The DASP rules establish when a command is saved and how a client recovers its result.

## Could an existing protocol be extended instead?

Yes. DASP's design choice is to keep actor recovery rules independent of a particular agent interaction model. A separate specification lets clients implement and test those rules across languages.

An extension or adapter could expose the same contract through another protocol. It would need to preserve command identity, authorization, outcomes, and replay, and document any limits.

## Can these protocols work together?

Yes, as separate interfaces in one system. An agent could accept an A2A task, call an MCP tool, and use a DASP session to control a durable actor.

This is a possible design. DASP has no released adapters. Start with the [build guide](../build/README.md) to review the host, client, and profile responsibilities.

---

*A2A, MCP, ACP, AHP, and AG-UI comparisons reviewed on 25 September 2026. Durable Streams added on 27 September 2026. Protocols can change. [Suggest a correction](../project/feedback.md).*
