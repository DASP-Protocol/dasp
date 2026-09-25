# Seigyo coding v1 baseline

Status: Audit baseline before protocol hardening

Date: 2026-09-20

This document records the coding v1 contract that the current endpoint
advertises. It is an audit input. The normative rules remain in the other
Seigyo documents. A later change to this file must follow a change to the
capability catalog and its tests.

The coding v1 transport is Phoenix Channel WebSocket. HTTP is not part of this
profile. Native Elixir calls are an implementation boundary and test aid. They
do not add a second client protocol.

## Scope

The current profile is `coding`, protocol version `1`. It has 21 operations,
two live controls, 11 request Signal types, 19 result Signal types, three push
Signal types, and ten durable Update variants. The server advertises no draft
operation, request type, or result type. The standalone `ContextCompacted`
push Signal remains draft; coding v1 reports compaction through an `Update`.

The following features are outside coding v1: HTTP, public Work or subagent
identity, Schedules, Session listing, ChangeSets, VerificationReports,
collaboration and OT, a general-agent profile, remote execution targets, and
multi-node fencing.

## Operation and client inventory

| WebSocket operation | Public client call | Typed client result |
| --- | --- | --- |
| `open` | `Jido.Seigyo.Client.open/2` | `Session` |
| `submit` | `submit_text/4` | `Receipt` |
| `updates` | `updates/3` | `UpdatesPage` with `Update` values |
| `history` | `history/3` | `HistoryPage` with `HistoryEntry` values |
| `view` | `view/3` | `View` |
| `trace` | `trace/4` | `Trace` with `Tool` values |
| `workspace_changes` | `workspace_changes/3` | `WorkspaceChanges` with `WorkspaceChange` values |
| `workspaces` | `workspaces/2` | `Workspaces` with `Workspace` values |
| `workspace_configure` | `configure_workspace/3` | `WorkspaceConfigured` |
| `execution_catalog` | `execution_catalog/2` | `ExecutionCatalog` with `ExecutionTarget` and `SandboxProfile` values |
| `configuration` | `configuration/3` | `SessionConfiguration` |
| `configuration_history` | `configuration_history/3` | `SessionConfigurationsPage` with `SessionConfig` values |
| `configure` | `configure/4` | `SessionConfigured` |
| `fork` | `fork/3` | `SessionForked` |
| `submit_turn` | `submit_turn/4` | `TurnReceipt` |
| `steer_turn` | `steer/5` | `TurnControlled` |
| `cancel_turn` | `cancel/4` | `TurnControlled` |
| `result` | `result/4` | `Result` with `ResultUsage`, `ResultReasoning`, and `ResultBlock` values |
| `attachment_begin` | `begin_attachment/3` | `Attachment` |
| `attachment_chunk` | `upload_attachment_chunk/5` | `Attachment` |
| `attachment_commit` | `commit_attachment/3` | `Attachment` |

The client also returns these nested values: `Capabilities`, `ModelConfig`,
`ContextConfig`, `SkillRef`, `PluginRef`, `ToolProfile`, `ExecutionConfig`, `SandboxConfig`,
`Message`, `ActiveCommand`, `CommandOutcome`, `ExecutionSummary`,
`WorkspaceSummary`, and `ResyncRequired`. Protocol failures use
`Jido.Seigyo.Error`. Connection, timeout, and invalid-server failures use
`Jido.Seigyo.Client.Error`. `Connection`, `Wire`, and `Value` are internal client
modules and are not application result values.

The live controls are:

| Control | Client call | Result and delivery |
| --- | --- | --- |
| `watch_updates` | `watch_updates/3` | Returns replay `UpdatesPage`; then delivers typed `Update` or `ResyncRequired` values. |
| `watch_progress` | `watch_progress/3` | Returns `:ok`; then delivers typed `Progress` values. |

`ack_update/2` is local client flow control for acknowledged live delivery.
`capabilities/1` reads the typed join manifest. `disconnect/1` is a local
connection operation. None is a durable protocol mutation.

## Signal inventory

### Client-to-server request Signals

| Module | Type |
| --- | --- |
| `SessionOpen` | `jido.client.v1.session.open` |
| `Command` | `jido.client.v1.command` |
| `SessionConfigure` | `jido.client.v1.session.configure` |
| `SessionFork` | `jido.client.v1.session.fork` |
| `TurnSubmit` | `jido.client.v1.turn.submit` |
| `TurnSteer` | `jido.client.v1.turn.steer` |
| `TurnCancel` | `jido.client.v1.turn.cancel` |
| `WorkspaceConfigure` | `jido.client.v1.workspace.configure` |
| `AttachmentBegin` | `jido.client.v1.attachment.begin` |
| `AttachmentChunk` | `jido.client.v1.attachment.chunk` |
| `AttachmentCommit` | `jido.client.v1.attachment.commit` |

### Server result Signals

| Module | Type |
| --- | --- |
| `SessionOpened` | `jido.client.v1.session.opened` |
| `Receipt` | `jido.client.v1.receipt` |
| `UpdatesPage` | `jido.client.v1.updates.page` |
| `HistoryPage` | `jido.client.v1.history.page` |
| `View` | `jido.client.v1.view` |
| `Trace` | `jido.client.v1.trace` |
| `WorkspaceChanges` | `jido.client.v1.workspace.changes` |
| `ExecutionCatalog` | `jido.client.v1.execution.catalog` |
| `SessionConfiguration` | `jido.client.v1.session.configuration` |
| `SessionConfigurationsPage` | `jido.client.v1.session.configurations.page` |
| `SessionConfigured` | `jido.client.v1.session.configured` |
| `SessionForked` | `jido.client.v1.session.forked` |
| `TurnReceipt` | `jido.client.v1.turn.receipt` |
| `TurnControlled` | `jido.client.v1.turn.controlled` |
| `Result` | `jido.client.v1.result` |
| `Failure` | `jido.client.v1.failure` |
| `Workspaces` | `jido.client.v1.workspaces` |
| `WorkspaceConfigured` | `jido.client.v1.workspace.configured` |
| `Attachment` | `jido.client.v1.attachment` |

### Server push Signals

| Module | Type | State |
| --- | --- | --- |
| `Update` | `jido.client.v1.update` | Current |
| `Progress` | `jido.client.v1.progress` | Current |
| `ResyncRequired` | `jido.client.v1.resync.required` | Current |
| `ContextCompacted` | `jido.client.v1.context.compacted` | Draft standalone type; not advertised |

## Durable Update inventory

| Event type | Command ID | Meaning |
| --- | --- | --- |
| `command_accepted` | Required | A `submit_text` command is active or queued. |
| `turn_started` | Required | A queued turn became active. |
| `turn_steered` | Required | A steering Mutation ID was applied. |
| `turn_cancel_requested` | Required | Cancellation of active work was requested. |
| `command_completed` | Required | Execution completed and a Result ID is available. |
| `command_failed` | Required | Execution has a known failure and a Result ID is available. |
| `command_cancelled` | Required | Work was cancelled and a Result ID is available. |
| `command_uncertain` | Required | The effect or Agent state is not known and a Result ID is available. |
| `session_configured` | Null | A configuration Mutation ID was applied or made pending. |
| `context_compacted` | Null | The server created a new context revision. |

Every row is present in `Jido.Seigyo.update_event_types/0` and in the closed
`Jido.Seigyo.Update` union. The acceptance suite proves each row across a
disconnect-at-commit boundary.

## Acceptance inventory

The executable acceptance inventory is the 65 `passing_slices` entries in
`apps/jido_code_acceptance/priv/seigyo/v1/manifest.json`. It maps to 53
scenario files. The current case families are:

- `SEIGYO-TEST-001` through `SEIGYO-TEST-010`;
- `SEIGYO-TEST-013`;
- `SEIGYO-TEST-018` through `SEIGYO-TEST-020`;
- `CODING-SESSION-001` through `CODING-SESSION-020`, including the
  `007-CONTEXT` and `008-LONG` variants.

The manifest entries are the complete slice-level list. A slice is not a
release claim unless its operation and types are also present in the live
capability manifest. The real SmolVM runtime test is an opt-in infrastructure
proof and is not an additional protocol case ID.

## Contradictions and open corrections

This baseline found these issues before behavior changes:

1. Resolved: the current Update union, capability catalog, and documents name
   the same ten variants.
2. Resolved: configuration and compaction have closed Update variants and
   disconnect-at-commit replay proof.
3. Resolved: coding v1 is WebSocket-only. HTTP remains future work.
4. Resolved: capability discovery, exact errors, coherent View, generated
   fixtures, and a raw live verifier have local WebSocket proof.
5. Resolved: the generated manifest and live endpoint both name version `1`,
   profile `coding`, and the same current capability set.
6. Resolved: conformance, the manifest, and implementation status describe
   active coding journeys through 020.
7. Resolved: Result usage has an explicit measurement state. Unknown provider
   counters stay `null` and never become zero.
8. Resolved: Result completion means execution completion only. It does not
   mean correctness, verification, approval, publication, or merge.
9. Resolved: file-backed Attachment declarations, chunks, ready content, and
   safe failure states recover after a server restart. The memory profile does
   not make that promise.
10. Resolved: Session state has a portable configuration digest, a bounded
    historical configuration read, and a server-owned tool-profile identity.
    Result and Trace carry this pinned provenance.
11. Resolved: `Jido.Seigyo.Catalog` owns one executable inventory for Signals,
    operations, controls, and proof links. `Jido.Seigyo.Release` generates the
    capability, operation, schema, frame, limit, and error catalog from it.
    `mix seigyo.bundle --check` rejects checked-in drift, and a mechanical
    acceptance test checks the generated cross-references.
12. The research file `apps/jido_seigyo/PASCAL_IDEAS.md` is not a normative
    protocol source and is not tracked. Accepted rules must move to the Seigyo
    documents, schemas, and conformance cases.

## Authority during hardening

Until coding v1 is frozen, use this order to resolve a mismatch:

1. An accepted ADR sets architectural direction.
2. `docs/seigyo/signals.md` owns normative wire shapes after it is corrected.
3. `Jido.Seigyo.Catalog` owns the executable inventory; Signal modules own
   their schemas; `Jido.Seigyo` publishes the advertised capability set.
4. The acceptance manifest and scenarios prove the endpoint behavior.
5. Client documentation describes, but does not create, protocol rules.

No current capability can be removed or changed silently. A breaking data
change needs an explicit compatibility rule, migration, or protocol version.
