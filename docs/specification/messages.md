# Messages and wire format

The imported contract uses CloudEvents-shaped Signals carried by Phoenix Channel WebSocket frames. It does not use the earlier JSON-RPC proposal.

Use the exact [frame fixtures](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/frames.json), [schemas](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/schemas.json), and [operation metadata](../../upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/operations.json).

A frame contains `join_ref`, `ref`, `topic`, `event`, and `payload`, in that order. The coding v1 topic is `client:v1`. The legacy join payload is `{"version":1,"profile":"coding"}`. The later opt-in offer has separate version, profile, required-feature, and optional-feature fields. See [initialization](../../upstream/seigyo/docs/seigyo/initialization.md).

Calls use an operation name and `request_ref`. Mutations carry a Signal. Reads carry typed arguments. Replies repeat the request reference. A Signal envelope ID names one delivery; it is not the durable Command ID or an Update cursor.

The source distinguishes `submit` from `submit_turn`. It also defines reads such as `view`, `updates`, `history`, and `result`. `watch_updates` and `watch_progress` control live delivery. They are not durable commands. Use the advertised catalog to determine support; do not infer support from a module or schema alone.

Read the [message rules](../../upstream/seigyo/docs/seigyo/messages.md), [Signal catalog](../../upstream/seigyo/docs/seigyo/signals.md), and [WebSocket ADR](../../upstream/seigyo/docs/adr/0019-client-websocket-wire.md) for full shapes and limits.
