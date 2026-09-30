# Runtime test cases

**Status: specified, not executed.** There is no runtime harness yet. These cases describe the observations required from future client and host implementations.

Each case uses a fresh isolated authority, session, and effect recorder. After the assertion, stop test processes and remove only that case's temporary storage. Record the core, binding, profile, and implementation versions. Bindings must supply concrete connection and fault controls before these cases can run.

## RUN-AUTHORITY-ADMISSION: Atomic admission and budgets

Requirements: **DASP-AUTH-003**, **DASP-AUTH-005**, **DASP-AUTH-007**. Status: not executed.

- Setup: One trusted issuer and agent, two permitted sessions, and reusable grants with no budget and with a budget of 100 admissions. Use multiple host replicas sharing one authority.
- Actions and failure: Submit many distinct commands, concurrent equal commands under different grants, and 101 distinct commands across both sessions. Lose receipts. Stop each replica before and after grant/use/budget/admission writes, commit, dispatch, and effects. Restart; retry equal intent with `recover`, renewed grants, and current delivery keys. End one session while the shared grant remains usable.
- Expected result: One admission and use per distinct accepted command. Equal retries preserve the original sequence and evidence and charge nothing. At most 100 new admissions use the bounded grant; the unbounded grant has no implicit one-use limit. No orphan charge, lost shared evidence, refund, or reset occurs. Unknown effects follow core uncertainty rules. Rejected work reserves no IDs or budget.
- Cleanup: Stop isolated replicas and remove only their stores and effect records.

## RUN-AUTHORITY-STATUS: Time, revocation, and current recovery/read permission

Requirements: **DASP-AUTH-005**, **DASP-AUTH-006**, **DASP-AUTH-007**. Status: not executed.

- Setup: An admitted command, a grant about to expire, independent recovery/read rights, and queued live and direct output.
- Actions and failure: Cross expiry during verification and commit. Revoke grant, issuer key, agent key, submit permission, recovery permission, and read permission separately. Make time or status unavailable. Race revocation with admission and final release. Keep signature verification cached. Repeat after key replacement and fresh setup.
- Expected result: No new admission under invalid current authority. A valid current recovery policy permits equal retries after grant expiry/revocation or grant-status outage. Unavailable current authentication or recovery permission reveals no record. Read access is independent and checked at release. Revocation closes affected attached connections without a protected head. No admission/outcome/history is rewritten and no implicit cancellation occurs.
- Cleanup: Close connections and remove this case's identities, stores, and queued output.

## RUN-AUTHORITY-BINDING: Required extension and encrypted composition

Requirements: **DASP-AUTH-002**, **DASP-AUTH-004**, **DASP-AUTH-007**, **DASP-AUTH-008**. Status: not executed.

- Setup: Complete authenticated plain and encrypted bindings selecting the same authority contract, scope schema, command rules, and limits.
- Actions and failure: Strip or change selection; omit the extension; send it on another type; send grant references or a wrapper; exceed each selected raw/decoded limit; rotate delivery keys. Attempt protected work on an unselected connection or with a weaker selected proof kind. Reject an authenticated command grant, then send the next connection record. Lose receipts and reconnect. Replay and push while read permission changes.
- Expected result: Unsupported or changed required selection fails before core traffic. Full evidence stays inside the encrypted core event. No plaintext fallback, new carrier field, wrapper, or skipped record is accepted. A rejected command consumes its authenticated connection record but no admission budget. Fresh ciphertext preserves retry equality and saved event identities. Live recovery uses fixed `H` and current reader rights.
- Cleanup: Close test connections and remove their isolated stores. Record setup, encryption, and authority coverage separately.

## RUN-AUTHORITY-TRUST: Independent proof bytes and scope enforcement

Requirements: **DASP-AUTH-001**, **DASP-AUTH-003**, **DASP-AUTH-004**, **DASP-AUTH-008**. Status: not executed.

- Setup: Two independent strict parsers/signature implementations and an issuer registry with purpose and scope restrictions. Use both session selectors and the optional direct mode.
- Actions and failure: Alter every signed field. Test untrusted/self-supplied/replaced keys, noncanonical Ed25519 public points/signatures, alternate base64 encodings, duplicate escaped keys, UTF-8, number rounding, and exact bounds. Use another agent, audience, actor, profile, session, command, or input resource. Attempt further delegation. Supply changed bytes under a known grant ID. Require direct approval, then submit only standing evidence.
- Expected result: Independent implementations agree on accepted bytes and signature failures. Exact configured trust and all scope restrictions are enforced before new work. Explicitly permitted sessions and many commands reuse the same standing evidence. Direct scope binds the complete target. No field or resource restriction is ignored; no grant proves human review.
- Cleanup: Remove only test keys, registry entries, and isolated application resources.

## RUN-ADMISSION: Crash at command boundaries

Requirements: **DASP-CORE-003**, **DASP-CORE-004**, **DASP-CORE-006**, **DASP-CORE-007**, **DASP-CORE-008**, **DASP-CORE-009**. Status: not executed.

- Setup: An authorized fresh command, an empty persistent session, and an external effect recorder that survives host restart. Expose fault points before admission commit, after admission commit, after dispatch, after the external effect, after outcome commit, and after receipt or outcome reply release. Include each admission and outcome write when the host uses separate stores. Run each point with fresh case storage.
- Actions and failure: Stop the host at each point. Retain the store and effect recorder; restart under the same authority. Retry equal intent with a new request ID. Read the outcome and replay all saved events. Run the external-effect point with conclusive effect evidence and with that evidence unavailable to the host. When authority proof is selected, also inspect its admission-use and budget records.
- Expected result: Before admission commit, there is no dispatch or visible acceptance. After commit, every equal retry identifies the original admission sequence. There is no second admission or grant charge. Proven undispatched work can start from its saved admission. After dispatch, recovery uses effect evidence; unresolved effects require saved uncertainty and no unsafe repeat. After outcome commit or outcome reply release, read and replay return the original terminal value, identity, and sequence. A receipt alone does not establish settlement. No terminal reply precedes its saved fact. Record actual dispatch and effect counts separately from admission counts.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-RETRY: Concurrent equal retries

Requirements: **DASP-CORE-002**, **DASP-CORE-003**, **DASP-CORE-004**. Status: not executed.

- Setup: A profile with two supported command names, two authorized sessions, at least three connections, and sufficient capacity. Start each run with one unused command ID and valid input for every competing intent.
- Actions and failure: Submit two equal attempts at the same time; lose one receipt, then retry. In separate fresh runs, race equal attempts with an authorized changed input, command name, or session under the same unused ID. Restart and retry each variant. Use a barrier at the admission decision to establish actual overlap.
- Expected result: Equal attempts converge on one admission sequence. In each changed-intent race, exactly one intent wins admission; all other intents conflict. Equal retries of the winner return its original sequence, including after restart. No losing intent dispatches, appends an admission, or changes the winner's saved retry data. A serial ordering evaluator alone does not pass this case.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-CONFLICT: Changed command identity

Requirement: **DASP-CORE-002**. Status: not executed.

- Setup: An admitted command and a second authorized session in the same authority.
- Actions and failure: Reuse its ID with changed input, command name, or session.
- Expected result: Each changed intent conflicts and creates no admission or execution.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-DISCONNECT: Lost connection

Requirements: **DASP-CORE-005**, **DASP-CORE-008**, **DASP-WS-005**. Status: not executed.

- Setup: An admitted command whose receipt has not reached the client.
- Actions and failure: Drop the connection, reconnect, and retry equal intent. Close an active connection with delivery queued. In a separate run, report transport receipt but stop before application admission.
- Expected result: The disconnect does not cancel admitted work. The host returns the original admission and saved outcome when settled. Transport receipt alone produces no accepted or settled application result. Close stops connection attachments without deleting history; output released earlier does not imply application.
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
- Actions and failure: Stop the client before and after each state, cursor, comparison-evidence, and checkpoint-commit write. Restart, replay equal and changed duplicates, remove comparison evidence, and present a gap or unknown event. Deliver a transport acknowledgment or transport gap signal without the missing saved fact. Reopen with a host head below the saved cursor.
- Expected result: State, cursor, and retained evidence recover as the complete old or new checkpoint, never a mixture. Equal duplicates are not applied twice. Changed duplicates fail; missing evidence requires a trusted projection or a stop. Transport signals cannot advance the applied cursor. The client never advances past a gap or unsupported saved event. A lower host head fails continuity without resetting the cursor.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-AUTH: Permission revocation

Requirements: **DASP-SEC-001**, **DASP-WS-006**. Status: not executed.

- Setup: A principal can read a session and an update, progress event, resync notice, or replay reply is queued.
- Actions and failure: Revoke permission, then retry a command, read, replay, and release queued output.
- Expected result: No protected saved decision or queued data is disclosed after revocation. Current authorization is checked before release. Revocation of read permission for an attached session closes its connection without protected session data or a head in the reason.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-RESTART: Persistent history

Requirements: **DASP-MODEL-001**, **DASP-CORE-009**, **DASP-CORE-012**. Status: not executed.

- Setup: A saved session, command record, terminal outcome, and client cursor.
- Actions and failure: Restart the host process, replace a worker, and reconnect both clients. Save another update. In isolated negative runs, make the store unreadable, remove it, or restore a stale copy that lacks acknowledged admissions or outcomes. Attempt recovery with the original authority and session identity.
- Expected result: Within the declared durability boundary, session identity, retry meaning, outcome, and event history survive. The next update continues the session sequence across worker and connection replacement. An unreadable store cannot be treated as an empty store. A lost or incomplete store cannot establish continuity under the same authority and session identity. No new admission is based on presumed absence of a lost record. Any stronger claimed failure boundary is tested separately.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-CAPACITY: Admission and retained storage

Requirements: **DASP-CORE-004**, **DASP-CORE-006**, **DASP-CORE-012**, **DASP-ENV-004**, **DASP-WS-004**. Status: not executed.

- Setup: A host with a declared finite storage limit, readable saved history, and one pending admitted command. Record how the implementation preserves space or otherwise handles required facts for admitted work. Use two authorized clients with different saved cursors.
- Actions and failure: Reach the admission capacity limit. Submit fresh work, retry an admitted command, read its outcome, and replay from both cursors. Attempt to settle the pending command. Separately fail its outcome write, then restore storage and restart. Overflow one client's live queue while the other reads history.
- Expected result: Unsupported fresh work is rejected before admission and dispatch. Capacity refusal preserves retry evidence, outcomes, and complete history. Reads and equal retries still work when the store remains readable. Failed outcome writes produce no false settled reply or published terminal update. Recovery uses saved admission and effect evidence after storage returns. A slow client's resync or close does not prune history or change the other client's cursor. No test assumes that a storage outage permits reads.
- Cleanup: Stop the isolated host and clients. Remove only this case's stores, checkpoints, and effect recorder.

## RUN-LIVE-OPEN: Open confirmation and repeated setup

Requirements: **DASP-WS-001**, **DASP-WS-002**. Status: not executed.

- Setup: A selected WebSocket binding and a saved session with active delivery.
- Actions and failure: Race commits with the first open. Complete a command immediately after confirmation and release all its saved pushes before its receipt. Repeat equal opens during replay and live use; deliver retained-stream pushes before and after the reply, including advancement beyond its captured head. Open a conflicting tuple. Resync before and after a pending open's host decision and confirmation. Delay an open reply past timeout and attempt recovery.
- Expected result: A new attachment covers every commit above its captured head and confirms before its pushes or progress. Immediate completion is applied in saved sequence order while its receipt remains pending; the receipt does not advance a cursor. Equal opens keep one attachment, its queued events, recovery target, and next push position; advancement beyond an equal-open reply does not fail continuity. A new attachment below the saved applied cursor still fails continuity. Conflicts preserve the old tuple and attachment. Open replies and resync follow state-transition order. Resync before a pending successful open reply makes that reply a new attachment confirmation. At most one open is pending per session; timeout requires connection close before a new attempt.
- Cleanup: stop this case's processes and remove its isolated sessions and captured output.

## RUN-LIVE-SCOPE: Several sessions and clients

Requirements: **DASP-WS-004**, **DASP-WS-005**, **DASP-WS-006**, **DASP-PROFILE-003**. Status: not executed.

- Setup: Two sessions on one connection and two clients with different applied cursors.
- Actions and failure: Interleave session output and request replies. Make one client slow enough to overflow its queue while the other reads. Resync one attachment, then close the connection. Reconnect clients and replay from their own saved positions. Exercise the binding's selected host-health deadlines; keep the transport open while withholding authenticated host responses.
- Expected result: Resource and request checks route each reply correctly. Resync affects one session unless the connection closes. Close stops both attachments and discards unsent output without cancelling commands or deleting history. Clients recover independently. A host delivery position is not a client cursor. A missed host-health deadline closes the connection; reconnection requires fresh authenticated setup and recovery from the saved applied cursor. Health checks use no periodic history polling and never advance a cursor.
- Cleanup: stop this case's processes and remove its isolated host records and client checkpoints.

## RUN-LIVE-POLLING: Required live selection and polling-only bindings

Requirements: **DASP-WS-001**, **DASP-PROFILE-001**, **DASP-PROFILE-002**, **DASP-MODEL-002**, **DASP-CORE-001**, **DASP-CORE-011**. Status: not executed.

- Setup: A configured secure endpoint, trusted host identity, one required-live WebSocket contract, declared receive limits, and a separately selected polling-only binding. Exact setup bytes remain complete-binding work.
- Actions and failure: Connect without automatic discovery. Select required live delivery on a host that cannot provide it. Substitute a contract or required feature; propose shared limits outside either peer's requirements, change selected values before confirmation, and attempt a core operation before mutual confirmation. Request an unsupported profile, change the profile on an existing session, and submit an unsupported command. Exercise local work-limit refusal or close. Then use the polling-only binding to discover and replay saved facts.
- Expected result: The configured endpoint still requires host authentication. Unsupported required live delivery, contract substitution, infeasible limits, or failed confirmation cannot create a session. Unsupported profiles create no session; changed profiles conflict without altering the saved tuple; unsupported commands create no admission. Both peers confirm the exact shared selection. Local controls remain bounded and cannot silently lose required saved facts. The separate polling-only binding requires no live attachment or handoff and preserves core replay, identity, cursor, and authorization rules.
- Cleanup: stop this case's processes and remove its isolated sessions and checkpoints.

## RUN-ENCRYPTION-VECTORS: Independent encrypted record vectors

Requirements: **DASP-ENC-001**, **DASP-ENC-002**, **DASP-ENC-003**. Status: not executed; optional binding rules in the unreleased draft.

- Setup: Two independent maintained HPKE implementations, Ed25519 implementations, pinned test keys, and exact agreed setup and record bytes. Do not use the synthetic carrier fixture as a cryptographic vector.
- Actions and failure: Exchange exact setup messages and records in both directions using controlled test-only randomness. Check setup transcript bytes, signing and reader-key proof inputs, mutual confirmation, encapsulation, ciphertext, pure Ed25519 signatures, protected bytes, HPKE info, and outer metadata. Change each authenticated setup field, signed record field, encapsulation, tag, and signature independently. Test the pinned point/signature acceptance policy, invalid registered keys, all-zero X25519 secrets, and maximum info length. Run raw integer and Unicode negatives with both independent parsers and real signatures.
- Expected result: Both implementations agree on positive setup and record vectors and reject tampered inputs. Parsing and re-encoding protected JSON is not a substitute for verification of original bytes. Shape validation alone does not pass this case.
- Cleanup: remove only the test keys, captured records, and temporary storage for this case.

## RUN-ENCRYPTION-AUTH: Encrypted delivery and setup

Requirements: **DASP-ENC-001**, **DASP-ENC-002**, **DASP-ENC-003**, **DASP-ENC-005**, **DASP-ENC-006**. Status: not executed; blocked by the complete setup contract.

- Setup: A complete selected encrypted WebSocket binding, a configured endpoint and trusted host keys, a trusted client, a relay, and isolated permission and key registries. No automatic discovery or enrollment service is required.
- Actions and failure: Submit before setup completes; omit or delay either peer's confirmation; prove only signing-key possession while lacking the reader key; substitute either signing or reader key; change authority, role, suite, profile, or limits; strip required encryption; replay old challenges and old connection records; introduce a gap or duplicate record; send plaintext or a nested carrier. Try self-registration through a setup message. Test registry failure, expired/revoked keys, known compromise, and trusted replacement. Revoke access with encrypted replies, progress, updates, or resync already prepared. Let the relay answer Ping/Pong while withholding host health responses; replay an old connection's health response.
- Expected result: Setup proves possession of both selected key purposes and confirms the same exact peer context, challenges, and settings before any core operation. A signing proof alone cannot satisfy reader-key possession. Required encryption has no plaintext fallback. Failed setup or confirmation timeout closes without a core reply or protected details. Invalid context or record order closes the connection. No session or work is admitted on failed setup. Messages cannot establish their own trusted registration, and a valid key alone grants no permission. Compromise, revocation, and replacement stop affected output and require fresh trusted setup; they do not recall records released earlier. Only a valid current-connection host health response satisfies the defined health check. A missed deadline closes; reconnection uses fresh setup and saved-cursor recovery without history polling.
- Cleanup: stop this case's host, clients, and relay; remove its isolated registry, keys, and storage.

## RUN-ENCRYPTION-RECOVERY: Retries and replay after key changes

Requirements: **DASP-ENC-004**, **DASP-ENC-005**, **DASP-CORE-002**, **DASP-CORE-003**, **DASP-CORE-009**, **DASP-CORE-010**. Status: not executed.

- Setup: Two permitted clients with separate keys and applied cursors, a persistent counter session, and an effect recorder.
- Actions and failure: Submit concurrent fresh encryptions of equal input. Lose a receipt, restart, replace a key through trusted administration, and retry through fresh setup. Try changed input under the same command ID. Run the live contract's normal, reconnect, resync, equal-open, and multi-page flows through actual carriers. Remove old network keys and replay with current keys. Open a new reader at a nonzero head with allowed or denied required history; try views, outcomes, and saved retry reads. Capture a delivery, rotate its reader key, then disclose the old test key.
- Expected result: Equal authorized intent has one admission and one execution decision. Changed intent conflicts. Saved identities, semantic data, and outcomes remain equal despite new encryption. Clients save state/cursor together, keep independent positions, and use the fixed live recovery target. Carrier numbers and discarded late replies never advance applied cursors. Required inaccessible history causes refusal without filtering or a fake cursor. Missing storage keys fail continuity. Later reader-key disclosure decrypts the captured test delivery, confirming the stated compromise limit rather than a secrecy guarantee.
- Cleanup: stop this case's processes and remove its isolated keys, effect recorder, checkpoints, and host storage.

## RUN-ENCRYPTION-LIMITS: Encrypted message and decoded input bounds

Requirements: **DASP-ENC-002**, **DASP-ENC-006**, **DASP-ENV-003**, **DASP-ENV-004**. Status: not executed.

- Setup: A selected encrypted binding with advertised bounds and allocation instrumentation.
- Actions and failure: Select shared values outside the contract's or either peer's bounds, with missing fields, invalid units/ranges, or changes before confirmation. Exercise concrete local limits that are not sent to the peer. Send exact-limit and one-byte-over messages, headers, ciphertext, and decrypted events. Fragment an oversized message into individually small frames; interleave controls and leave messages incomplete. Include whitespace, multibyte metadata, noncanonical base64url, duplicate keys, BOM, invalid UTF-8, rounded fractional/exponent record tokens, prohibited characters, oversized saved facts, and deep/overfull containers. Select IDs whose aggregate header fails now or at maximum record width. Reopen with tighter limits that cannot replay an existing one-event page. Send a valid inner event whose carrier exceeds the core byte limit. Inject cryptographic library failures.
- Expected result: Both peers authenticate and confirm exact, feasible shared values with defined units; invalid selection cannot start core traffic. Local allocation, cumulative message bytes, parser/decode work, and fragment deadlines stay bounded before authentication, and local control failures use defined refusal, resync, or close behavior. Core limits apply after decryption; the larger carrier uses its own cap. Duplicate keys and exact token/Unicode violations fail consistently without normalization. Infeasible selection or history recovery fails before core operations or attachment confirmation. No invalid message is admitted. Failure causes neither plaintext fallback nor truncated facts. Oversized required output is rejected before its command is admitted.
- Cleanup: stop this case's processes and remove its allocation records and isolated storage.

## RUN-ENCRYPTION-ORDER: Record consumption and queue discard

Requirements: **DASP-ENC-003**, **DASP-ENC-004**, **DASP-ENC-005**, **DASP-WS-004**, **DASP-WS-006**. Status: not executed; blocked by the complete setup contract.

- Setup: A selected encrypted connection with two sessions, pending replay requests, instrumented output release, and separate counters in both directions.
- Actions and failure: Follow an authenticated invalid-profile request with another valid record. Deliver cancelled pages and failures before and after new open confirmation, then current replies for the other session. Queue provisional encrypted A and B output after released record 40; stop A before release and discard its updates/progress. Race revocation with final release. Inject an uncertain transport handoff. Send authenticated invalid inner UTF-8/JSON and invalid host replies as separate close cases.
- Expected result: Authentication consumes each consecutive record once before application validation/discard. A rejected request or discarded reply cannot leave its old number expected. Invalid inner parsing or host data closes without advancing a saved cursor. Queue discard creates no released gap: B can use 41 and A's resync 42, with fresh rebuilt encryption where needed. No stopped-stream output follows resync; the other session remains active unless the connection closes. Current key/permission checks and release are ordered with revocation. Uncertain handoff closes without number reuse. All counters reset only after fresh setup.
- Cleanup: stop this case's host, clients, and relay; remove its isolated keys, captured records, queues, and checkpoints.
