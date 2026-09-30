# Protocol capabilities

**Status: draft-01, unreleased.** DASP defines durable sessions and recovery. Its first WebSocket delivery rules, optional payload encryption, and optional proof of authority use the same core. The repository has experimental TypeScript and Elixir clients. It does not yet have a complete interoperable binding or a persistent example host.

This page explains how the contracts fit together. The linked requirements define their exact behavior. See [conformance coverage](../../conformance/README.md) for the limits of the evidence.

## One core, separate responsibilities

| Part | Capability | Current implementation and evidence |
| --- | --- | --- |
| [Core](README.md) | Five requests: open a session, submit a command, read a view, read updates, and read an outcome. Fourteen message types define admission, saved results, progress, and recovery. | Schemas, recorded cases, and client message checks. Host durability and concurrent admission tests remain open. |
| [Application profile](profiles-and-bindings.md) | Defines commands, inputs, state, completion, concurrency, and application errors. | The counter profile supplies a concrete example. A production application needs its own specified rules. |
| [WebSocket live delivery](websocket-live-delivery.md) | Session open starts live observation. Replay recovers saved events to a fixed boundary. Normal delivery requires no history polling. | Shared recorded cases and both client recovery implementations. Exact connection setup, health controls, shared limits, and host runtime tests remain open. |
| [Encrypted delivery](payload-encryption.md) | Encrypts one complete core event for its reader. The host can read commands and history. Relays cannot read the payload under the specified trust and cryptographic assumptions. | Carrier/header schemas and parsing checks. Fixtures use synthetic ciphertext and signatures. Setup, independent cryptographic agreement, expert review, and runtime tests remain open. |
| [Proof of authority](proof-of-authority.md) | A signed standing grant permits many commands within a work scope and time window. A shared admission-count limit is optional. Exact-command grants are also defined. | Closed schemas, valid signatures checked by one implementation, and recorded admission decisions. Host enforcement, concurrent budget tests, and independent security evidence remain open. |
| [Language clients](../../clients/README.md) | Construct requests, check replies, route duplex traffic, recover live streams, and apply ordered updates to checkpoints. | TypeScript and Elixir package tests, including the shared live cases. Applications supply authenticated transport, profile rules, and durable storage. |

Encryption and proof of authority are optional capabilities of a selected binding. Each becomes required where the selected contract or host policy requires it. An unsupported required capability must fail selection. A client cannot remove a required proof or select plaintext to bypass host policy.

The WebSocket rules are the first delivery contract. Separate polling-only bindings remain valid. None of these additions changes the five core requests, fourteen core message types, core schema shapes, or protocol version.

## How a command uses these parts

1. The peers authenticate each other and confirm the exact core, profile, binding, required features, and limits. Core traffic must wait for setup to finish. The complete setup wire format remains work for the binding.
2. The client opens the session. The host captures saved head `H` and attaches later live updates without a commit gap. The client replays from its saved cursor through `H`, then applies buffered live updates.
3. If authority is required, the agent puts its signed grant in the `daspauthority` CloudEvents extension. The grant stays outside profile input. In encrypted mode, the extension is inside the encrypted core event.
4. The host authenticates and decrypts the record, validates the core event, and checks the command ID and current permission. For new intent, it verifies scope and saves admission, retry data, grant use, and any budget charge atomically before dispatch.
5. The host saves updates and a terminal outcome. It checks current read permission before releasing output. Encrypted output uses each permitted reader's current keys. The client saves its applied state, cursor, and duplicate evidence together.

Authentication identifies a peer. A grant limits new work. Encryption protects content. Admission records accepted intent. A terminal outcome records the result. None of these facts substitutes for another.

## One grant, many commands, safe retries

A principal can sign one grant that permits `counter.add` within stated amount limits for eight hours. Its scope can list several sessions or explicitly cover sessions for one actor and profile. The agent can submit several distinct command IDs under that grant. A grant with no admission-count limit does not need a new signature for each command.

Each new command has its own admission and grant-use record. If the grant has a budget, new admissions across its permitted sessions share that budget. An equal retry uses the original command ID, session, command name, and complete input. It adds no admission or budget charge. The client uses a new request ID and, in encrypted mode, fresh delivery encryption.

After grant expiry or revocation, current independent recovery permission can still permit an equal retry of saved intent. The `recover` extension value can request that recovery; it cannot admit new work. Changed input under an admitted command ID remains a conflict. Read access is checked separately and is not granted by a command grant.

## Recovery keeps the same saved facts

A connection loss stops delivery, not admitted work. Reconnection uses fresh setup and the original session tuple. Replay returns the original saved identities and data after the client's last applied cursor. A key change does not rewrite history or execute commands again.

The host must supply all history needed for an authorized reader's recovery or refuse attachment. It must not hide sequence gaps by filtering history. Read revocation for an attached session stops protected output and closes the connection. Each client keeps its own applied cursor.

DASP does not guarantee exactly-once external effects. An effect that cannot be established can require a saved `uncertain` outcome. Delivery encryption also does not protect readable host storage or make earlier captured ciphertext safe after later compromise of its static reader key.

## Work required before release

Complete the authenticated setup bytes, key-possession proofs, mutual confirmation, shared limits, health controls, and deadlines as one binding contract. That setup must bind required authority selection as well as encryption settings. Test agreement between independent cryptographic implementations and obtain security review.

Implement and test a persistent host with both clients. Tests must cover admission and budgets under concurrent requests, restart, queued output after revocation, encrypted retries, replay, and connection loss. Passing artifact or client tests alone does not satisfy these requirements. The [encryption release requirements](payload-encryption.md#release-requirements), [authority evidence requirements](proof-of-authority.md#dasp-auth-008), and [runtime cases](../../conformance/behavioral-cases.md) record the remaining work.
