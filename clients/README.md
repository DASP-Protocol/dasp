# Language clients

Elixir and TypeScript are the first DASP client targets. Both will implement the same [CloudEvents core draft](../docs/specification/README.md), selected application profile, and transport binding.

| Language | Current status |
| --- | --- |
| [Elixir](elixir/README.md) | Source client imported; DASP draft client not implemented |
| [TypeScript](typescript/README.md) | DASP draft client not implemented |

Client APIs can follow language conventions. Wire values, retry identity, receipt meaning, and applied-cursor behavior must remain the same. Neither client may require a chat interface.

The imported source client is reference material. It is not compatible with the new draft without an adapter. A binding and profile must be fixed before interoperable client releases.
