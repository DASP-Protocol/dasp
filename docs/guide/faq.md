# Why DASP? FAQ

DASP defines a common contract for durable actor sessions. These short answers explain why that contract needs its own specification and how it relates to other protocols.

Comparisons reviewed on **25 September 2026**. They describe design scope, not conformance results. DASP is a working draft. No production host, transport binding, or client package is released.

## Why another protocol?

We need clients to control a durable actor, share its session, and recover after a lost connection. The same contract must define saved command admission, retries, final outcomes, and replay of saved updates. It must also let the application define its own commands without requiring chat or turns.

The protocols below address related needs. DASP brings these requirements together in a generic actor contract. Without that common contract, each integration must define the missing rules itself. See the [core requirements](../specification/recovery.md).

## Why not A2A?

Agent2Agent (A2A) supports communication between agents through messages, tasks, and artifacts. It already supports long-running tasks, streaming, and reconnecting clients. Its specification makes duplicate detection for Send Message optional. See the [A2A specification](https://a2a-protocol.org/latest/specification/).

DASP requires equal command retries to resolve to one saved admission. It also defines ordered replay for a generic actor session, with a saved position for each client. Use A2A when agent task exchange meets your needs; DASP addresses the actor host's durable command contract.

## Why not MCP?

The Model Context Protocol (MCP) connects AI applications to tools and context. Its Tasks extension adds durable task handles and recovery of polling after a restart. See the [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28) and [Tasks extension draft](https://tasks.extensions.modelcontextprotocol.io/specification/draft/tasks).

DASP specifies a shared actor session that can contain many commands, saved outcomes, and an ordered update history. A durable tool task covers part of this need. DASP makes session recovery and command retry rules part of the same core contract.

## Why not ACP?

The Agent Client Protocol (ACP) defines communication between code editors and coding agents. It gives that integration a common interface. See the [ACP introduction](https://agentclientprotocol.com/get-started/introduction).

DASP serves actor hosts and clients beyond the editor. An actor can be an agent, workflow, or device controller. An application profile defines its commands and results. Choose ACP for editor integration; consider DASP when the shared resource is a durable actor session.

## Why not AHP?

The Agent Host Protocol (AHP) has close overlap: multiple clients can share synchronized AI agent sessions. Its channel model includes sessions, chats, terminals, and other resources. See the [AHP introduction](https://microsoft.github.io/agent-host-protocol/guide/what-is-ahp.html).

DASP starts with generic actors and commands. Its core specifies saved admission, immutable final outcomes, explicit uncertainty, and replay. The application defines its state and command vocabulary. Chat can be an application profile; it is not required by the DASP core.

## Why not AG-UI?

The Agent User Interaction Protocol (AG-UI) connects agent runtimes to user interfaces through events and shared state. It addresses how an application presents agent activity and accepts user interaction. See the [AG-UI introduction](https://docs.ag-ui.com/introduction).

DASP defines what the actor host saves and what a client can recover. That contract can support a user interface, command-line tool, or background service. A UI event stream and a durable session contract address different parts of an application.

## Why not CloudEvents alone?

CloudEvents defines a common event envelope, including identity, source, type, and data. It leaves application behavior to other specifications. See [CloudEvents 1.0.2](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md).

DASP uses that envelope. It adds the rules for command admission, outcomes, ordering, and recovery. A valid CloudEvent alone does not establish that a command was saved or that an update can be replayed. See the [DASP CloudEvents envelope](../specification/cloudevents.md).

## Could an existing protocol be extended instead?

An extension is a possible implementation approach. It still needs to define the actor model, retry identity, saved outcomes, and recovery rules that clients share. DASP gives those rules one specification that can be reviewed and tested across languages. A mapping to another protocol would need to preserve them and state any limits.

## Can these protocols work together?

They can serve different interfaces in one system. For example, an agent could accept an A2A task, call an MCP tool, and use a DASP session to control a durable actor. This is a possible architecture, not an integration that DASP currently provides. Adapters need explicit mappings for identity, authorization, outcomes, and recovery.

Start with [use cases](use-cases.md) to assess the fit, or read [how to add DASP to a project](../build/README.md).
