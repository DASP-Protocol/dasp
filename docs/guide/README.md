# How DASP works

The connection drops. The work may still be running.

DASP gives a client a way to return, check the result, and read what it missed. A TUI, web app, or test driver can use the same actor session.

## Five operations

<CommandOverview />

An **actor** performs the work. A **host** manages its sessions and saved records. A **session** ties one actor and application profile to an ordered history.

## Acceptance and completion

A receipt says the command was accepted, already accepted, or rejected. Acceptance means the host saved the intent. It does not mean the work finished.

A saved outcome records one result: **completed**, **failed**, **cancelled**, or **uncertain**. An outcome read can also report that the command is pending.

## Saved facts and temporary progress

**Updates** are saved facts: acceptance, application events, and final outcomes. Each update has a sequence number. A client saves its last applied position, called a **cursor**, with its state.

**Progress** reports activity. It can be lost. A **view** gives the saved application state at a specific cursor.

[Follow a command](../build/walkthrough.md) to inspect the messages, lose a receipt, and retry the same command.

## Where it fits

Use DASP when work must survive client connections and more than one client needs the same record. Examples include an agent controlled by a TUI, an operator watching automated work, or a workflow reporting saved results.

Your application defines its commands and completion rules in a **profile**. A **binding** defines transport and authentication. DASP supplies the common session behavior.

For a single tool call or an editor integration, another protocol may already fit. [Compare DASP with A2A, ACP, MCP, and other protocols](faq.md).

## Current state

DASP is a working draft with experimental Elixir and TypeScript clients. Its [capability overview](../specification/capabilities.md) connects core recovery, live delivery, optional encryption, and reusable authority grants. No production binding or host is released. It does not guarantee exactly-once external effects.

[Start building](../build/README.md) or learn [why DASP uses CloudEvents](cloudevents.md).
