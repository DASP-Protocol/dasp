# Runtime test cases

**Status: specified, not executed.** There is no runtime harness yet. These cases describe the observations required from future client and host implementations.

Each case uses a fresh isolated authority, session, and effect recorder. After the assertion, stop test processes and remove only that case's temporary storage. Record the core, binding, profile, and implementation versions. Bindings must supply concrete connection and fault controls before these cases can run.

## RUN-ADMISSION: Crash during admission

Requirement: **DASP-CORE-004**. Status: not executed.

- Setup: An authorized fresh command and an empty persistent session.
- Actions and failure: Stop the host at each save/dispatch boundary, then restart and retry the same intent.
- Expected result: No accepted receipt exists without its saved admission. No unrecorded command is dispatched. An equal retry returns one admission sequence.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-RETRY: Concurrent equal retries

Requirement: **DASP-CORE-003**. Status: not executed.

- Setup: Two authorized connections, one unused command ID, and identical input.
- Actions and failure: Submit both attempts at the same time; lose one receipt, then retry.
- Expected result: One admission update and one execution decision exist. Both accepted/duplicate receipts identify the same admission.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-CONFLICT: Changed command identity

Requirement: **DASP-CORE-002**. Status: not executed.

- Setup: An admitted command and a second authorized session in the same authority.
- Actions and failure: Reuse its ID with changed input, command name, or session.
- Expected result: Each changed intent conflicts and creates no admission or execution.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-DISCONNECT: Lost connection

Requirements: **DASP-CORE-005**, **DASP-WS-005**. Status: not executed.

- Setup: An admitted command whose receipt has not reached the client.
- Actions and failure: Drop the connection, reconnect, and retry equal intent. Close an active connection with delivery queued.
- Expected result: The disconnect does not cancel work. The host returns the original admission and saved outcome when settled. Close stops connection attachments without deleting history; output released earlier does not imply application.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-OUTCOME: Stale completion

Requirement: **DASP-CORE-006**. Status: not executed.

- Setup: An admitted command with an already saved terminal outcome.
- Actions and failure: Deliver a second completion from an old worker; read the outcome and replay.
- Expected result: The original outcome and its event identity remain unchanged. No second terminal outcome appears.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-UNCERTAIN: Unknown external effect

Requirement: **DASP-CORE-007**. Status: not executed.

- Setup: A command can cause an external effect and the test cannot determine whether it occurred.
- Actions and failure: Lose ownership after dispatch; restart the host without conclusive effect evidence.
- Expected result: The host saves uncertainty and prevents unsafe repeat execution. It does not claim success or rollback without evidence.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-REPLAY: Gaps and live handoff

Requirements: **DASP-CORE-009**, **DASP-CORE-011**, **DASP-WS-002**, **DASP-WS-003**, **DASP-WS-004**. Status: not executed.

- Setup: A session with saved updates and a client with a persistent cursor.
- Actions and failure: Commit after head capture but before confirmation receipt, then during several replay pages. Return a page head newer than the open boundary. Overflow host and client buffers, fail to queue resync, order resync around reopen, and deliver late pages and failures for locally cancelled replay requests before and after new confirmation. Follow each discarded reply with a reply to a current request.
- Expected result: Open confirms before pushes for a new attachment, without blocking later commits. Replay through the fixed open boundary and buffered later events cover every saved sequence without a second application or a chasing loop. Saved identities match. Host overflow ends the affected attachment and sends resync or closes; client overflow closes and recovers. No stopped-stream update follows resync. Reopen starts new delivery and new replay requests. Cancelled pages and failures change no application or attachment state. Current replies still reach their callers.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-CURSOR: Client state and cursor

Requirements: **DASP-CORE-010**, **DASP-WS-003**. Status: not executed.

- Setup: A client applies updates and persists a projection.
- Actions and failure: Stop the client between application and persistence; restart, replay equal and changed duplicates, remove duplicate-comparison evidence, and present a gap or unknown event. Reopen with a host head below the saved cursor.
- Expected result: State and cursor recover together. Equal duplicates are not applied twice. Changed duplicates fail; missing evidence requires a trusted projection or a stop. The client never advances past a gap or unsupported saved event. A lower host head fails continuity without resetting the cursor.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-AUTH: Permission revocation

Requirements: **DASP-SEC-001**, **DASP-WS-006**. Status: not executed.

- Setup: A principal can read a session and an update, progress event, resync notice, or replay reply is queued.
- Actions and failure: Revoke permission, then retry a command, read, replay, and release queued output.
- Expected result: No protected saved decision or queued data is disclosed after revocation. Current authorization is checked before release. Revocation of read permission for an attached session closes its connection without protected session data or a head in the reason.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-RESTART: Persistent history

Requirement: **DASP-CORE-012**. Status: not executed.

- Setup: A saved session, command record, terminal outcome, and client cursor.
- Actions and failure: Restart the host process and reconnect both clients.
- Expected result: Session identity, retry meaning, outcome, and event history survive. Any stronger claimed failure boundary is tested separately.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-LIVE-OPEN: Open confirmation and repeated setup

Requirements: **DASP-WS-001**, **DASP-WS-002**. Status: not executed.

- Setup: A selected WebSocket binding and a saved session with active delivery.
- Actions and failure: Race commits with the first open. Repeat equal opens during replay and live use; deliver retained-stream pushes before and after the reply, including advancement beyond its captured head. Open a conflicting tuple. Resync before and after a pending open's host decision and confirmation. Delay an open reply past timeout and attempt recovery.
- Expected result: A new attachment covers every commit above its captured head and confirms before its pushes or progress. Equal opens keep one attachment, its queued events, recovery target, and next push position; advancement beyond an equal-open reply does not fail continuity. A new attachment below the saved applied cursor still fails continuity. Conflicts preserve the old tuple and attachment. Open replies and resync follow state-transition order. Resync before a pending successful open reply makes that reply a new attachment confirmation. At most one open is pending per session; timeout requires connection close before a new attempt.
- Cleanup: stop this case's processes and remove its isolated sessions and captured output.

## RUN-LIVE-SCOPE: Several sessions and clients

Requirements: **DASP-WS-004**, **DASP-WS-005**, **DASP-WS-006**, **DASP-PROFILE-003**. Status: not executed.

- Setup: Two sessions on one connection and two clients with different applied cursors.
- Actions and failure: Interleave session output and request replies. Resync one attachment, then close the connection. Reconnect clients and replay from their own saved positions. Exercise the binding's selected host-health deadlines; keep the transport open while withholding authenticated host responses.
- Expected result: Resource and request checks route each reply correctly. Resync affects one session unless the connection closes. Close stops both attachments and discards unsent output without cancelling commands or deleting history. Clients recover independently. A host delivery position is not a client cursor. A missed host-health deadline closes the connection; reconnection requires fresh authenticated setup and recovery from the saved applied cursor. Health checks use no periodic history polling and never advance a cursor.
- Cleanup: stop this case's processes and remove its isolated host records and client checkpoints.

## RUN-LIVE-POLLING: Required live selection and polling-only bindings

Requirements: **DASP-WS-001**, **DASP-PROFILE-002**, **DASP-CORE-011**. Status: not executed.

- Setup: A configured secure endpoint, trusted host identity, one required-live WebSocket contract, declared receive limits, and a separately selected polling-only binding. Exact setup bytes remain complete-binding work.
- Actions and failure: Connect without automatic discovery. Select required live delivery on a host that cannot provide it. Substitute a contract or required feature; propose shared limits outside either peer's requirements, change selected values before confirmation, and attempt a core operation before mutual confirmation. Exercise local work-limit refusal or close. Then use the polling-only binding to discover and replay saved facts.
- Expected result: The configured endpoint still requires host authentication. Unsupported required live delivery, contract substitution, infeasible limits, or failed confirmation cannot create a session. Both peers confirm the exact shared selection. Local controls remain bounded and cannot silently lose required saved facts. The separate polling-only binding requires no live attachment or handoff and preserves core replay, identity, cursor, and authorization rules.
- Cleanup: stop this case's processes and remove its isolated sessions and checkpoints.
