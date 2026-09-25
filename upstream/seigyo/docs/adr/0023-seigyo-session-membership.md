# ADR 0023: Model Session membership as explicit Actor grants

Status: Accepted
Date: 2026-09-21

## Context

Seigyo coding version 1 permits only the Session owner to use a Session. Jido
Code needs durable multiplayer Sessions. A participant can be a human client
or a Jido Actor client.

Jido agents can also delegate work to subagents. A subagent is execution
topology. It is not a client identity and it must not receive Session access
because its parent delegated work to it.

The coding version 1 release bundle is frozen. Session membership must not
change that bundle for clients that do not select the extension.

## Decision

Define the negotiated feature `seigyo.membership/1`.

A Session member is one durable Actor Instance with an access role. The Actor
has kind `human` or `actor`. The access role is `owner`, `editor`, or `viewer`.
An internal execution Actor Instance with role `agent` is not a Session member.

Both human and Actor clients authenticate as a stable principal. Authentication
is outside the Signal data. The server resolves the trusted principal to an
Actor and an active Actor Instance. Signal `source`, Actor IDs in request data,
and Jido parent or child relationships do not grant access.
One principal source reference resolves to exactly one Actor kind, so a human
and an Actor client cannot share an ambiguous principal.

An owner can add a registered Actor, change a member role, or remove a member.
The first owner grant is created with the Session. A Session must keep at least
one active owner. One Actor can have at most one active member Actor Instance in
one Session.

The feature defines closed operations to list members, add a member, change a
role, remove a member, and read saved Command attribution. Each mutation has a
Mutation ID and an expected Session revision. A mutation, its audit event, and
the Session revision change are one Store transaction.

A Command saves the submitting member Actor Instance at admission. The server
derives this value from the trusted caller. A client cannot submit it. This
attribution remains after role changes, member removal, and restart.

Removing a member denies new calls and closes all live attachments for that
Actor. Work accepted before removal can finish. Presence and connection count
are temporary data and never grant access.

## Roles

| Operation | Viewer | Editor | Owner |
| --- | --- | --- | --- |
| Open, read, and attach | Yes | Yes | Yes |
| Submit work | No | Yes | Yes |
| Control own work | No | Yes | Yes |
| Control another member's work | No | No | Yes |
| Configure, fork, and manage members | No | No | Yes |

Workspace ownership stays separate from Session membership. A member can use
the Workspace through the Session execution boundary. Membership does not let
the member list or configure the owner's other Workspaces.

## Consequences

The existing Actor and Actor Instance resources remain the identity model. No
second Session member identity is added. Storage adapters need a portable
member projection of those resources.

Clients that do not select `seigyo.membership/1` keep the frozen coding version
1 contract. A collaborative Session records the feature as a saved requirement.

Jido root agents and subagents stay outside the member list unless a separate,
registered Actor principal receives an explicit member grant and connects as a
client.
