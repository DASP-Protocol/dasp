> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Shared conformance plan

Status: planned. These cases are requirements for a future test suite, not tests that have passed.

Use one language-independent set of JSON fixtures and one controllable test host. Run the same cases for Elixir and TypeScript. Check state and stored outcomes after failures, not only response shapes.

| Case | Required observation |
| --- | --- |
| Version mismatch | Structured error, then connection close |
| Request before initialization | `NOT_INITIALIZED` |
| Repeat session open | Same binding; no second session |
| Session identity conflict | `SESSION_CONFLICT` |
| Retry after lost success response | Same output and revision; one commit |
| Concurrent command duplicate | One outcome; no duplicate mutation |
| Same command identity, changed input | `COMMAND_CONFLICT` |
| Stale expected revision | Stored `REVISION_CONFLICT`; no application execution |
| Retry terminal rejection | Same stored error after state changes |
| Crash before commit | No partial state or success record |
| Crash after commit | Original result survives restart |
| Competing actor owners | No divergent committed history |
| Subscribe during commit | Snapshot followed by every later revision |
| Disconnect during command | Unknown outcome resolved with original identity |
| Reconnect after many changes | Current snapshot replaces stale state |
| Revision above 2^53 | Exact comparison and round trip |
| Gap or malformed update | View becomes non-current; new snapshot required |
| Slow consumer | Explicit connection loss; no silent update loss |
| Concurrent close and command | Actor order determines result |
| Duplicate command after close | Original stored outcome |
| Revoked access | No protected updates; connection closes |
| Tenant isolation | No cross-tenant state or command result access |
| Unknown method and invalid input | Defined JSON-RPC errors |

Add fixtures under this directory when schemas are introduced. Include request/response traces, expected final snapshots, and expected durable command records. Mark each case with the protocol version it covers.
