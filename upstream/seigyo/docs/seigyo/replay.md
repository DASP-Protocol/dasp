# Seigyo Protocol: replay and local application

These rules clarify coding v1 delivery. They add no wire field or operation.
The frozen coding v1 bundle remains unchanged. The reference implementation is
`Jido.Seigyo.Replay`; the language-neutral examples are
`apps/jido_seigyo/priv/seigyo/replay-v1/vectors.json`.

## Ordered facts and application

**SEIGYO-REPLAY-001.** A Session has one durable Update sequence domain. Its
first sequence is 1. Each saved Update has the next integer. Session revision,
configuration revision, context revision, Agent revision, Progress sequence,
Signal ID, and request reference are separate values. A server saves a fact
before it publishes its Update. Publication failure does not remove that fact.

An applied cursor is the last contiguous Update successfully applied to one
consumer's state. Reading, validating, buffering, or sending an Update does
not prove application. The consumer must save its state and applied cursor
atomically, or use an idempotent application operation. The protocol does not
make an external consumer effect exactly once.

**SEIGYO-REPLAY-002.** Compare duplicate Updates by validated canonical data
at `(session_id, sequence)`. Ignore Signal envelope IDs and JSON key order.
Ignore a duplicate only when this comparison proves equivalence. Different
data at the same key is a protocol fault. Stop application at that fault.
The typed client ends the connection and fails outstanding calls. A server
subscription that detects a conflict pauses and sends `ResyncRequired`.

**SEIGYO-REPLAY-003.** Validate the closed envelope, role, source, type, and
bounded data before application. Bind replies to their request reference,
requested Session, and requested Command where applicable. For an Updates
page, also check the echoed cursor, each Update's Session, contiguous order,
page limits, and `next_cursor`. An unknown or unreadable saved event is an
error; a server must not omit it and move the cursor forward. Validate a
Result's status, error, content, and provenance before it supplies outcome
truth. A terminal Update points to the saved Result; it does not contain it.

Progress is a replacement snapshot ordered only within its Command. Ignore
old Progress; discard later Progress after learning the saved outcome. Never
use Progress or a Trace to advance an Update cursor or establish a Result.
Validate a View before use. Its `event_cursor` is a coherent read watermark,
not proof that the consumer has applied every preceding Update.

**SEIGYO-REPLAY-004.** Duplicate evidence must be bounded. The reference helper
keeps 256 fingerprints by default and accepts a window of 1 to 1000. SHA-256
covers the complete canonical Update data: recursively sort object keys,
keep array order, encode UTF-8 strings as JSON without normalization, use
base-10 integer values, and use JSON boolean/null literals. No floats occur
in these Updates. The helper does not hash the Signal envelope.

If old duplicate evidence has expired or a restart restored only a cursor,
the helper reports `gap` for an old delivery. It does not guess equivalence.
The client requests resynchronization. Restart with a read strictly after the
saved cursor; retain fingerprints with local state if old overlap must be
verified. The server currently retains all saved Updates. A future retention
floor must produce `gap` below that floor; it cannot silently skip history.

## Replay, live delivery, and replacement

**SEIGYO-REPLAY-005.** `ack_update/2` is local client flow control. It sends no
server acknowledgement. With `delivery: :acknowledged`, apply and acknowledge
each returned replay-page Update in order. Then apply and acknowledge each
live Update. An acknowledgement must match the complete in-flight value.
An out-of-order, changed, repeated, or paused acknowledgement fails without
advancing. Buffered live data waits until replay application completes.

The existing `:automatic` mode remains the default. It advances a delivery
position when it returns a page or sends a message to the receiver. That
position is not a durable applied cursor. Use acknowledged delivery when
application success must control local delivery. The caller still owns
persistent state and the cursor used after a reconnect.

**SEIGYO-REPLAY-006.** A watch is scoped to one Session and connection. Another
successful watch for that Session replaces its receiver, delivery mode, and
replay baseline. Other Sessions and connections have independent watches.
The typed client permits only one pending replacement per Session. Wait for
its reply before another replacement. There is no wire detach operation;
close the connection to detach all its watches. A dead local receiver pauses
its local delivery until replacement. Messages already in an old receiver's
mailbox cannot be recalled; the application must stop that receiver before
it transfers ownership of consumer state.

For attach, register a bounded publication buffer before reading saved
Updates. Seed the subscription's comparison state from that replay cut.
Drain equal overlap without sending it again. Send only the next contiguous
fact. A missing sequence, unverifiable overlap, or buffer overflow pauses
live delivery and sends `ResyncRequired`. A failed replacement does not
establish a live baseline; the client pauses the old watch. The server removes
a subscription whose replay failed after registration.

A full attach page has `next_cursor: null`. The current server rejects attach
when more than 100 saved Updates remain. A byte-bounded incomplete page may
still have `next_cursor`; the client returns it and pauses live delivery with
`ResyncRequired`. Apply the readable prefix, page through saved Updates, and
replace the watch from the last saved applied cursor. Overflow and reconnect
follow the same recovery rule. A gap or invalid frame never permits a cursor
jump. A valid View alone is insufficient to recover a full event ledger or
conversation history. A consumer can install a View as a fresh checkpoint
only if that View covers all state it needs and it accepts the declared loss
of older detail. It must record this new baseline explicitly.

**SEIGYO-REPLAY-007.** Saved Results and replay do not depend on diagnostic
publication or retention. A disconnected client or unavailable execution
snapshot can lose all Progress and tool trace detail while the saved Result
and Updates remain readable. Read the Result for outcome truth. Trace
availability and loss indicators have their own rules; Update retention does
not promise Trace retention. If a publication is lost with no later live
Update, a client cannot detect the loss from silence. Read the saved stream
or a View watermark when freshness is required.

## Finite recovery algorithm

**SEIGYO-REPLAY-008.** To bound catch-up while writers continue, read a View
watermark `H` once, without changing the applied cursor `C`. Read pages after
`C` with `limit = min(page_size, H - C)`. Validate and apply each Update,
saving state and cursor together. Stop when `C == H`, even if `next_cursor`
is non-null because later facts exist. Use a finite page budget or deadline.
If application or a read fails, return the last saved `C`; do not set it to
`H`. New writes can be read in the next pass or by a watch after `C`. The v1
page format needs no added high-water field for this algorithm.

**SEIGYO-REPLAY-009.** The pure reference reducer follows this algorithm:

```text
check(state, update):
  validate complete Update data and Session identity
  if update.sequence == state.cursor + 1: return APPLY
  if update.sequence > state.cursor: return GAP
  if fingerprint absent: return GAP
  if stored fingerprint equals hash(update): return DUPLICATE
  return CONFLICT

consume(state, update):
  decision = check(state, update)
  if DUPLICATE: return unchanged state
  if error: stop without advancing
  apply update to consumer state
  if application fails: keep the last saved consumer state and cursor
  commit the new consumer state, cursor, and bounded fingerprint evidence
```

`Replay.check/2` performs the first phase without mutation. `Replay.commit/2`
returns the next reference state; call it only after application succeeds.
The JSON vectors record `check`, whether application reaches `commit`, and
the resulting cursor. Unit model checks cover page cuts, equal duplicates,
partial application, and restart. An independent consumer can implement this
algorithm without loading an Elixir module.
