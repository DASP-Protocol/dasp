# Seigyo Protocol: Collaboration

## Users, members, and shared documents

**Proposed collaboration extension.** This section needs an ADR and a new
protocol version or negotiated capability. It does not change the current v1
Signal shapes or the first coding transport proof. It applies to native and
remote clients through the same Server facade.

| ID | Proposed behavior |
| --- | --- |
| SEIGYO-COLLAB-001 | A stable User may have several temporary Clients and a durable Session Member grant. |
| SEIGYO-COLLAB-002 | The Server checks a trusted User's grant on every read, submit, edit, and attach. |
| SEIGYO-COLLAB-003 | Saved Command attribution names its submitting User after restart. |
| SEIGYO-COLLAB-004 | Every authorized attached Client can receive one User's committed Session Updates. |
| SEIGYO-COLLAB-005 | One document authority orders, transforms, and saves each accepted text delta at one document revision. |
| SEIGYO-COLLAB-006 | A stale Client can get a document snapshot without silent loss of its unacknowledged input. |

### Identity and access

The adapter authenticates a User. The Server derives `user_id` from trusted
caller context. A Client ID identifies one attached tab or app instance; one
User may have several Clients. A Session has durable Members. Start with
`owner`, `editor`, and `viewer`: an owner can manage grants and submit work;
an editor can submit work and edit shared documents; a viewer can read and
attach. The owner grant is created with the Session. Grant changes are saved
and audited. A client cannot claim a role, User ID, or Client ID in a Signal.
The Server checks grants on every open retry, read, submit, document edit,
and attach. A grant removal also closes that User's live attachments. A
command admitted before removal continues under its saved admission; removal
does not silently cancel Agent work. The saved revocation stops new admission
and invalidates that User's attachments. A frame already sent may still
arrive. An API node must check the current grant epoch before it prepares a
new push; an old grant cache cannot authorize it. The Store must order the
grant check with admission and attach. Later cancel policy must be
explicit. If two Users try to create the same Session ID, only the winning
create grants ownership. The other caller gets a result that reveals no
private Session data.

The CommandRecord saves the submitting User ID at admission. A repeat from
another Client of that same User returns the same admission and author. A
different User cannot reuse that Command ID, even with identical input; the
Server rejects it without changing the original record. The Server first
authorizes the caller for the Session.
Safe command and outcome projections include author attribution. A User
summary exposes only an ID and an approved display name. Session membership
and author data survive restart. Presence is temporary: the Phoenix transport
can use Phoenix Presence to track authorized connections and send bounded
join, leave, and optional selection notices. Native clients can use the same
temporary presence meaning without a Phoenix dependency. Presence never
grants access or settles work. It needs no Session Update sequence. A fresh
presence snapshot replaces missed notices after reconnect. Keep Presence
metadata small and free of secrets; read durable User data from the Store.

One User can submit a Command while every authorized attached Client receives
its saved Updates and optional Progress. Each Client keeps its own Session
Update cursor. The Server must fan out from committed Store events and enforce
access on each attachment. This is the multiplayer rule for conversation and
agent work. It needs no text transformation.

### Operational transformation for shared text

Operational transformation (OT) applies only when two Clients edit the same
shared text. The first candidate is a Session draft or named scratchpad. An
accepted draft is copied into a normal `Command` input at submission; later
draft edits cannot change that Command's saved input or retry identity. Agent
output and the saved conversation remain append-only results. Workspace Git
files retain Workspace and Git write rules; adding live file editing needs a
separate file save and conflict contract.

A shared document has a stable Document ID, text snapshot, document revision,
and a bounded history of accepted deltas. The Session collaboration authority
serializes edits for that document and saves the new text and revision before
it acknowledges an edit. The Store profile must save the document state and
enough transform history for its stated recovery window. Document revisions
start at zero and increase once per accepted edit. They do not consume Jido Code
Session event sequences. A document delta is not a Jido Code Command or an Agent
request. The document authority cannot admit Agent work.

The client sends a stable operation ID, Document ID, base revision, and a
bounded delta. A lost reply must be retried with the same operation ID and
unchanged base revision and delta. The Server verifies the caller's edit grant
and that the delta is valid for the text at its base revision. It transforms
the incoming delta
over all accepted edits after that revision, with a specified tie rule for
simultaneous inserts. It saves the transformed delta at the next revision,
replies with an acknowledgement, and broadcasts the accepted delta to every
authorized attachment. A repeat operation ID returns the original accepted
revision and delta; changed data with that ID conflicts. The Store must keep
the operation ID and its accepted result for the stated retry window even if
old transform history is removed. A Client applies
accepted revisions in order and transforms its pending local edits against
them. It matches its own acknowledgement and broadcast by operation ID, so it
applies that accepted edit once. It does not infer commit from a local editor
change or a lost reply.

If the base revision is older than retained transform history, the Server
returns a resync result whose wire type and error mapping the OT ADR must
fix. The Client fetches a fresh snapshot and must preserve its unacknowledged
local input for an explicit rebase or user
choice. It must not silently discard that input. A reconnect uses the last
applied document revision separately from the Session Update cursor. The
first OT profile uses UTF-16 code unit offsets to match JavaScript editor
selection positions, as [Livebook's Delta module](https://github.com/livebook-dev/livebook/blob/main/lib/livebook/text/delta.ex)
does. A delta must not split a Unicode surrogate pair or produce invalid
text. The exact delta grammar, transform tie rule, operation ID scope,
history window, size limits, and snapshot persistence rule need an ADR and conformance tests before
implementation. Livebook's [Session data model](https://github.com/livebook-dev/livebook/blob/main/lib/livebook/session/data.ex)
is useful prior art for serialized operations and per-document revisions.
Jido Code need not depend on Livebook itself.

```mermaid
sequenceDiagram
    participant A as Client A
    participant B as Client B
    participant S as Document authority
    A->>S: delta op A, base revision 7
    B->>S: delta op B, base revision 7
    S->>S: save A at revision 8
    S-->>A: acknowledge A at 8
    S-->>B: applied A at 8
    S->>S: transform B over A; save at revision 9
    S-->>B: acknowledge B at 9
    S-->>A: applied B at 9
```
