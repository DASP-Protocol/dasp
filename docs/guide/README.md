# What is DASP?

DASP is the **Durable Actor Session Protocol**. It is an open, language-independent protocol for controlling durable actors through shared sessions. It defines command admission, saved outcomes, ordered updates, and recovery using CloudEvents messages.

## Why a session matters

An actor can continue work after its client disconnects. The client needs to know which command was accepted, which result was saved, and which updates it missed. A second client needs the same facts without taking ownership of the first connection.

DASP gives the client and host a common contract for these questions. A connection carries messages. A session keeps the identity and saved history for the work.

## Who it serves

DASP is for agent builders connecting interfaces, tools, and automation to durable actors. It also supports other actors that perform application work. The actor can be a workflow, device controller, or agent. Its protocol identity does not name an in-memory process.

## The boundary

| Layer | Responsibility |
| --- | --- |
| CloudEvents | Event identity, source, type, and metadata |
| DASP core | Sessions, command admission, saved outcomes, updates, and recovery |
| Application profile | Commands, inputs, outputs, state, completion, and domain errors |
| Transport binding | Connection setup, selection, authentication, routing, and delivery |
| Host implementation | Actor execution, scheduling, and storage |

The core does not require chat or turns. A profile can define them when the application needs them.

## What the guarantees mean

An accepted receipt is evidence of saved admission. An outcome is evidence of what the host can establish about execution. Progress is temporary. A failure to establish external effects remains explicit as an uncertain outcome.

Equal command retries do not create a second admission. This does not promise exactly-once external effects. Those effects need application-level controls.

More than one authorized client can read a session and submit profile commands. Each client saves its own applied cursor. Presence, membership roles, and shared editing need further contracts.

## Current state

Draft-01 contains core requirements, JSON Schemas, examples, and artifact checks. It is open for technical review and can change. No production binding, host, or client package is released.

Continue with [core concepts](concepts.md), [use cases](use-cases.md), or [the build guide](../build/README.md).

For short answers about A2A, MCP, and other protocols, read [Why DASP? FAQ](faq.md).
