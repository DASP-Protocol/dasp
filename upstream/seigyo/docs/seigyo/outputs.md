# Seigyo Protocol: output and diagnostic limits

These rules preserve coding v1 message shapes. A schema alternative alone
does not advertise a server feature.

## Content and retrieval

**SEIGYO-OUTPUT-001.** A saved Result is immutable. Read it with `result`,
using Session and Command IDs. A terminal Update supplies the Result ID.
The server checks Session ownership before it returns content. Missing or
inaccessible Session or Command IDs return `not_found`; read failure returns
`unavailable`. The file Store retains Results across process restart. The
memory Store retains them for its process lifetime. Neither has timed Result
expiry. There is no public delete or expiry operation in v1.

The current server emits two block types:

| Block | Meaning and retrieval |
| --- | --- |
| `markdown` | Inline UTF-8 Markdown, at most 32,768 bytes. `truncated` declares omitted text. The Result contains all retained text. Omitted text has no separate retrieval operation. No digest or media download is needed for this inline value. |
| `workspace_changes` | Workspace identity for a live `workspace_changes` read through the owning Session. The response contains paths, change types, and a bounded UTF-8 patch. It describes the Workspace at read time. It has no immutable content digest, media download, expiry time, or promise to retain the bytes present when the Result was saved. |

A later Command can change Workspace files while the earlier Result stays
identical. A remote client reads the protocol patch and does not need access
to the server filesystem. Do not infer historical file bytes from this reference.

**SEIGYO-OUTPUT-002.** Attachment input, Artifact output, and Result have
different lifetimes. Input reuses Attachment identity and declaration; it
does not share an output block union. The declaration fixes Session, name,
media type, decoded byte size, SHA-256, and purpose. Ordered chunk uploads
remain incomplete until commit verifies size and digest. Ready or rejected
content cannot change. Repeat the same `attachment_begin` declaration to read
saved state and resume at `next_chunk_index`. The file profile retains partial
uploads and committed content across process restart. There is no timed expiry
or public content download. New turns can use only ready Attachments from
their own authorized Session. Unknown upload IDs return `not_found`; missing
or wrong-Session turn references produce a rejected Receipt. Store failure
returns `unavailable`.

The frozen Result schema also accepts `attachment`, `artifact`, and `citation`
blocks. The current server does not produce or advertise those output features.
It has no Artifact store or retrieval operation. These remain reserved
compatibility shapes. Decoder acceptance does not make a reference retrievable.
An implementation must define and select a complete retrieval contract before
it advertises those outputs. This work adds no streamed or appendable Artifacts.

## Bounds and loss

**SEIGYO-OUTPUT-003.** Apply numeric, collection, and UTF-8 bounds before
use. Count text bytes after JSON decoding, except for explicit encoded JSON
limits. Never split a UTF-8 code point when shortening text.

| Value | Bound and overflow |
| --- | --- |
| WebSocket text frame | 524,288 encoded bytes; reject or close on overflow |
| Signal | 512,000 encoded JSON bytes; `too_large` |
| Update page | 262,144 encoded JSON bytes and 100 items; paginate within the bound |
| JSON integer | Absolute value at most 9,007,199,254,740,991; fields also enforce their nonnegative range |
| Request reference / Command text | 128 / 8,192 UTF-8 bytes; reject excess input |
| Session instructions / Progress text | 16,384 UTF-8 bytes |
| History entry text / Workspace patch | 4,000 / 65,536 UTF-8 bytes; declare truncation |
| Result blocks | 50 blocks; value-cost budget 262,144: 128 bytes per block plus UTF-8 bytes of each string value. The historic name says `json_bytes`, but this budget is not serialized JSON length. Enclosing Signal and frame limits still apply. |
| Attachment | 104,857,600 decoded bytes; each chunk at most 65,536 decoded bytes. Base64 expansion is not content size. |
| Trace | 100 tool entries; 16,384 UTF-8 bytes of permitted thinking text. Tool labels retain the frozen schema's 128-character bound. Duration fields are nonnegative integer milliseconds. |
| Portable generic value | Value-cost budget 16 KiB; four container levels; 32 map keys; 64 list items. Closed profile objects have their own schema limits. |

**SEIGYO-OUTPUT-004.** The reference client permits 128 pending calls by
default. `max_pending_requests` selects 1 through 1,024. Excess calls fail
locally with `too_large/requests` before transmission. Reply or timeout frees
the slot. The server closes before it forwards a 129th unanswered application
request. Saved admission survives a connection close; reconnect and retry
with the same durable identity.

The client permits 64 watched Sessions by default; `max_watched_sessions`
selects 1 through 100. Pending watches count. Replacing the same Session does
not use another slot. Excess new watches fail with `too_large/watched_sessions`.
Retained cursor state counts until disconnect.

Acknowledged delivery holds one delivered live Update and at most
`max_pending_updates` queued Updates per Session (default 256; range 1 through
1,000), plus one replay page. Overflow pauses delivery and requires replay.
The server subscription has a separate bounded queue (default 64). Automatic
delivery does not bound the caller's mailbox. Use acknowledgement after local
application when controlled delivery is required. Replay fingerprints have
a bounded window.

The client retains at most 4,096 Progress sequence and terminal evidence entries.
At that diagnostic budget it stops optional Progress for the connection and
clears the diagnostic cache. Result reads and Update replay continue. It does
not evict terminal evidence and then emit late Progress as new work. Total
storage and authenticated connections need deployment quotas; per-value and
per-connection bounds do not claim a total service quota.

**SEIGYO-OUTPUT-005.** Truncation is loss, not pagination. A bounded View
can direct a client to saved History and Updates. Truncated Result text, tool
output, Trace data, and Workspace patches have no v1 operation to retrieve
omitted bytes. A later Workspace read need not reconstruct them. Render the
retained prefix and its loss indicator.

## Diagnostic evidence and privacy

**SEIGYO-OUTPUT-006.** Trace is an observed diagnostic prefix.
`truncated: false` means no known loss within that observation, not proof of
every runtime event. Missing diagnostic data, upstream truncation, or the
tool limit sets `truncated: true`. After recovery a completed Trace can have
no tools, null duration, zero observed calls, and known loss, while the saved
Result still reports original usage. A missing terminal diagnostic never
reverses a saved Result or establishes another outcome.

Trace uses public Session and Command IDs. Configuration revision, digest,
and tool profile come from saved admission. Model and usage are observations,
not provider attestations. Duration uses milliseconds. Do not infer an absolute
timestamp from a duration or sequence number.

**SEIGYO-OUTPUT-007.** Public errors contain only code and optional field.
Trace failure reasons have an allowlist; unknown adapter data becomes
`request_failed`. Tool summaries contain only bounded status, exit code,
file-change, or output-limit facts. Remote reads hide thinking by default.
Server operation error logs omit raw exceptions and provider terms. Dependency
logs and deployment telemetry need separate access controls; they are not
public protocol data.

Authorized Workspace configuration can contain host and runtime paths.
Workspace changes can contain relative paths. Preserve these explicit fields
and check ownership. Do not put arbitrary paths, credentials, provider replies,
runtime process IDs, or topology into Failure or Trace.

The [W3C Trace Context recommendation](https://www.w3.org/TR/2021/REC-trace-context-1-20211123/)
was reviewed for optional correlation. Its fields propagate cross-service
correlation and vendor state. Coding v1 does not add them to the closed envelope
or use them for authority. A future selected extension needs privacy, size,
and trust rules. Retry and replay use existing public IDs and sequences.
