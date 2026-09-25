# Language clients

Elixir and TypeScript are the first DASP client targets. They must share the imported contract and its conformance fixtures.

| Language | Current status |
| --- | --- |
| [Elixir](elixir/README.md) | Existing Seigyo client imported unchanged; DASP package extraction remains |
| [TypeScript](typescript/README.md) | Source design proposal exists; implementation remains |

Clients must preserve the distinction between Receipt, saved Update, Result, View, and temporary Progress. A retry keeps the same Command ID and data. Applied cursor persistence belongs to the application. Client APIs may use language conventions, but their wire values must satisfy the same closed schemas and limits.

The imported client and source documents retain Seigyo names. This project has not published a renamed DASP package.
