# Recovery

The source separates command admission, saved outcomes, and temporary Progress. A Receipt alone is not a completed result.

After a lost reply, retry the same Command ID and exact data. A changed command needs a new ID. In the imported core rules, the same Command ID in another Session conflicts. The earlier proposal's session-local duplicate key is superseded.

Save the applied Update cursor with application state. Resume saved Updates after that cursor. Update sequences are safe JSON integers, not the decimal strings from the earlier proposal. Reject gaps and changed data for an existing replay key before advancing the applied cursor.

The Elixir client offers automatic delivery tracking and acknowledged delivery. Automatic delivery does not prove that the application applied an Update. In acknowledged mode, apply and save each Update before acknowledgment. Live overflow requires replay. A new connection must recover from the last applied cursor.

The source has separate Session Store and Agent checkpoint authorities. It does not claim one atomic commit across them. Recovery must preserve uncertain outcomes when execution evidence is incomplete. The file storage profile proves process restart, not power-loss survival or exactly-once external effects.

Full rules: [delivery](../../upstream/seigyo/docs/seigyo/delivery.md), [processing](../../upstream/seigyo/docs/seigyo/processing.md), [replay](../../upstream/seigyo/docs/seigyo/replay.md), and [session lifetime](../../upstream/seigyo/docs/seigyo/session-lifetime.md).
