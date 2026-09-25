> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Core specification

Status: proposed `0.1.0-draft.1`.

## Purpose

DASP connects clients to durable actors through durable sessions. It defines identity, command results, state observation, duplicate command handling, and recovery. It does not define actor placement, process scheduling, storage engines, cluster membership, or application command types.

## Terms

| Term | Meaning |
| --- | --- |
| Actor | A logical entity with a stable identity and application behavior |
| Host | A service that implements DASP and controls durable storage |
| Session | A durable interaction record bound to one actor |
| Connection | A temporary transport link between a client and host |
| Command | A request to change application state or perform application work |
| Commit | An atomic durable record of a command outcome and any session change |
| Revision | A sequence number for committed changes within one session |
| Snapshot | The complete client-visible session state at one revision |
| Subscription | A connection-local stream of committed session snapshots |
| Principal | The identity established by the deployment's authentication system |

An actor can have multiple sessions. Each session belongs to exactly one actor. Session state is a view defined by the application; it need not contain all actor state. Actor identity and session identity MUST survive process restart and movement between hosts within the same service.

The host MUST serialize commands for each actor, including commands from different sessions. DASP does not define order between different actors or transactions across actors. Concurrent requests take the order selected by the host. Clients MUST NOT infer order from request identifiers.

## Identity and data

The service assigns the namespace for actor and session identifiers. Identifiers are non-empty, case-sensitive opaque strings. Clients MUST NOT interpret identifiers as process addresses or credentials. Clients create session identifiers for retry-safe `session.open` calls. A host MUST NOT reuse a session identifier for another actor.

Messages use UTF-8 JSON. JSON objects MUST NOT contain duplicate keys. Application payloads use JSON values. Binary values, dates, and large application numbers require an application schema; the base protocol does not define automatic conversion.

Revisions are decimal strings matching `0|[1-9][0-9]*`. They have no fixed numeric limit. Clients MUST compare them numerically, not lexically. Revision `"0"` identifies the initial snapshot. Each committed session change increments the revision by one. Revisions MUST NOT reset after restart.

A snapshot has these required fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `sessionId` | string | Session identity |
| `actorId` | string | Bound actor identity |
| `revision` | decimal string | Last committed change |
| `status` | string | `open` or `closed` |
| `state` | JSON value | Complete application view |

A closed session permits observation and result lookup. It rejects new commands. Closing a session does not delete the actor. Deletion and session expiry are outside this first draft. Core command records remain available for the lifetime of their session, including after close.

## Transport and connection

The transport MUST provide complete, ordered messages in both directions while connected. A broken connection can leave a request outcome unknown.

The first transport profile uses WebSocket. Each text message contains one JSON-RPC 2.0 object. WebSocket fragmentation does not change that rule: the receiver reassembles a complete message before parsing. JSON-RPC batches and binary WebSocket messages are not supported by this profile. Other transports require a separate framing profile.

Request identifiers MUST be non-empty strings unique among pending requests on that connection. Responses carry the same identifier. A response contains either `result` or `error`, never both. A notification has no identifier and receives no response. Mutation methods MUST be requests, not notifications.

The client MUST complete `initialize` before other requests. Each new connection requires a new initialization. Successful initialization does not restore subscriptions. See the [message reference](messages.md).

A disconnect ends subscriptions. It MUST NOT close sessions or cancel accepted commands. Hosts MUST reject oversized messages and disconnect slow consumers when bounded output queues fill. Hosts MUST NOT silently omit committed updates on a live subscription.
