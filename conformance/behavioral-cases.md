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

Requirement: **DASP-CORE-005**. Status: not executed.

- Setup: An admitted command whose receipt has not reached the client.
- Actions and failure: Drop the connection, reconnect, and retry equal intent.
- Expected result: The disconnect does not cancel work. The host returns the original admission and saved outcome when settled.
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

Requirement: **DASP-CORE-009**. Status: not executed.

- Setup: A session with saved updates and a client with a persistent cursor.
- Actions and failure: Disconnect, add facts, reconnect, replay while more facts arrive; overflow any live buffer.
- Expected result: The client recovers every required saved fact in order. Replayed identities match. Overflow triggers resync where live delivery exists.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-CURSOR: Client state and cursor

Requirement: **DASP-CORE-010**. Status: not executed.

- Setup: A client applies updates and persists a projection.
- Actions and failure: Stop the client between application and persistence; restart, replay duplicates, and present a gap or unknown event.
- Expected result: State and cursor recover together. No update is applied twice; the client never advances past a gap or unsupported saved event.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-AUTH: Permission revocation

Requirement: **DASP-SEC-001**. Status: not executed.

- Setup: A principal can read a session and a live delivery is queued.
- Actions and failure: Revoke permission, then retry a command, read, replay, and release queued output.
- Expected result: No protected saved decision or queued data is disclosed after revocation. Current authorization is checked.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-RESTART: Persistent history

Requirement: **DASP-CORE-012**. Status: not executed.

- Setup: A saved session, command record, terminal outcome, and client cursor.
- Actions and failure: Restart the host process and reconnect both clients.
- Expected result: Session identity, retry meaning, outcome, and event history survive. Any stronger claimed failure boundary is tested separately.
- Cleanup: stop this case's processes and remove its isolated test storage and effect records.

## RUN-ENCRYPTION-VECTORS: Independent encrypted record vectors

Requirements: **DASP-ENC-002**, **DASP-ENC-003**. Status: not executed; proposed binding only.

- Setup: Two independent maintained HPKE implementations, Ed25519 implementations, pinned test keys, and exact agreed setup and record bytes. Do not use the synthetic carrier fixture as a cryptographic vector.
- Actions and failure: Exchange records in both directions. Check shared encapsulation, ciphertext, signatures, protected-byte inputs, and outer metadata. Change each signed field, encapsulation, tag, and signature independently.
- Expected result: Both implementations agree on positive vectors and reject tampered records. Parsing and re-encoding protected JSON is not a substitute for verification of original bytes. Shape validation alone does not pass this case.
- Cleanup: remove only the test keys, captured records, and temporary storage for this case.

## RUN-ENCRYPTION-AUTH: Encrypted delivery and setup

Requirements: **DASP-ENC-001**, **DASP-ENC-002**, **DASP-ENC-003**, **DASP-ENC-005**. Status: not executed; blocked by the complete setup contract.

- Setup: A complete selected encrypted WebSocket binding, a trusted host and client, a relay, and isolated permission and key registries.
- Actions and failure: Submit before setup completes; substitute a peer key; strip required encryption; replay old challenges and old connection records; introduce a gap or duplicate record; send plaintext or a nested carrier. Revoke access with an encrypted reply or live record already queued.
- Expected result: Setup proves the selected peer context before any core operation. Required encryption has no plaintext fallback. Invalid context or record order closes the connection without protected error details. No work is admitted on failed setup. Revocation stops further output; it does not recall records released earlier. A valid key alone grants no permission.
- Cleanup: stop this case's host, clients, and relay; remove its isolated registry, keys, and storage.

## RUN-ENCRYPTION-RECOVERY: Retries and replay after key changes

Requirements: **DASP-ENC-004**, **DASP-ENC-005**, **DASP-CORE-002**, **DASP-CORE-003**, **DASP-CORE-009**, **DASP-CORE-010**. Status: not executed.

- Setup: Two permitted clients with separate keys and applied cursors, a persistent counter session, and an effect recorder.
- Actions and failure: Submit concurrent fresh encryptions of equal input. Lose a receipt, restart, replace a key through trusted administration, and retry through fresh setup. Try changed input under the same command ID. Replay while live updates arrive. Remove old network keys and repeat replay with current keys.
- Expected result: Equal authorized intent has one admission and one execution decision. Changed intent conflicts. Delivery ciphertext and IDs can change while saved identities, semantic data, and settled outcomes remain equal. Clients save state and cursor together, keep independent positions, and recover through the selected live-delivery contract. Missing storage keys fail continuity rather than creating an empty history under the same identity.
- Cleanup: stop this case's processes and remove its isolated keys, effect recorder, checkpoints, and host storage.

## RUN-ENCRYPTION-LIMITS: Encrypted frame and decoded input bounds

Requirements: **DASP-ENC-002**, **DASP-ENC-006**, **DASP-ENV-003**, **DASP-ENV-004**. Status: not executed.

- Setup: A selected encrypted binding with advertised bounds and allocation instrumentation.
- Actions and failure: Send exact-limit and one-byte-over frames, headers, ciphertext, and decrypted core events. Include excessive whitespace, multibyte metadata, noncanonical base64url, duplicate JSON keys, invalid UTF-8, oversized saved events, nested profile containers, and overfull replay pages. Inject cryptographic library failures.
- Expected result: The receiver bounds allocation before decoding or cryptographic work and enforces inner limits after decryption. Duplicate keys are rejected before parsing discards them. No invalid message is admitted. Failures never cause plaintext fallback or truncated saved facts. Oversized required output is rejected before its command is admitted.
- Cleanup: stop this case's processes and remove its allocation records and isolated storage.
