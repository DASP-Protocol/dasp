# TypeScript client proposal

Status: Design only. No TypeScript client is built.

A TypeScript client against the Elixir server is a useful first external
consumer of this protocol. It will make missing wire details visible before
a mobile client depends on them. The client can power a browser coding
harness. Its core package can also serve a later mobile UI.

The core package should have no Elixir imports and no Phoenix LiveView
dependency. It handles envelope checks, IDs, retry, Receipt and Failure,
View cursor, ordered Update data, pages, and WebSocket recovery. A selected
profile supplies closed Command input, View content, optional Trace and
Progress, and Update variant schemas. Add `listSessions` when its page
contract is fixed. Later profiles can add Work, Schedule, Member, and
document operations when their schemas are fixed. One state reducer should
apply ordered Updates, replace temporary Progress when present, detect gaps,
and request replay. The caller provides authentication, storage for its
last applied cursor, and a transport. A changed draft must get a new
Command ID; a retry keeps the same ID and exact data.

Implement the current Phoenix Channel WebSocket frames first. Use calls for
bounded reads and commands, and replay Updates after reconnect. A later plain
JSON WebSocket or HTTP adapter must keep the same Signal data, Receipt meaning,
and replay rules. The UI must not be the authority for Agent, Session, or Work
state.

Build the package from the published wire schemas, with fixtures that are
shared with the independent conformance bundle. A TypeScript compile
and fixture test can catch a schema change. A black-box test against the
Elixir server can catch an implementation mismatch. Keep UI components
outside the core client package, so a browser harness and a mobile app can
use the same protocol logic.

Before implementation, publish the external authentication flow and portable
fixtures for the accepted WebSocket frames, capability discovery, and resume
rules. The current Elixir client and in-repository acceptance suite are the
reference implementation and proof. This document is a client design note,
not a source of new wire requirements.
