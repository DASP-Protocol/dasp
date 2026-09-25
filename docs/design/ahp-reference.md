# Microsoft AHP reference

[Microsoft Agent Host Protocol](https://github.com/microsoft/agent-host-protocol) is a comparison reference. DASP's source is Jido Seigyo.

The local AHP clone is in `reference/agent-host-protocol/`. Reviewed commit: `296b25e7b698a4a84a0ee5a28d9573e70048a0bf`.

AHP defines JSON-RPC messages, channel subscriptions, and state synchronization. Seigyo's imported contract uses Signals, admission Receipts, saved Updates, and a Phoenix Channel binding. Do not replace Seigyo's wire contract with AHP messages without a separate design and compatibility decision.

The earlier AHP-based DASP proposal is archived. The Microsoft clone retains its original license and notices.
