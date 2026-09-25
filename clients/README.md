# Language clients

Elixir and TypeScript are the first DASP client targets. **Neither client is implemented or released.**

| Language | Status | Package | Compatibility |
| --- | --- | --- | --- |
| Elixir | Planned | Not published | Not established |
| TypeScript | Planned | Not published | Not established |

Both clients will implement the same selected core, profile, and binding. Their APIs can follow language conventions. Command identity, admission, outcomes, and cursor behavior must keep the same meaning.

## Elixir

Keep wire decoding, profile validation, transport, and recovery separate. Do not create atoms from untrusted names. A process restart needs recovery from saved caller state; supervision alone does not establish protocol durability.

## TypeScript

Keep safe integer values and validate wire objects before use. A receipt must not resolve an API that promises a completed outcome. Save the applied cursor with the corresponding projection.

## First implementation target

Specify one binding, connect both clients to a persistent example host, and run the shared recovery cases. Publish the supported core, profile, and binding versions with each package. Package version numbers alone do not establish compatibility.

Start with [the build guide](../docs/build/README.md), [schemas](../docs/reference/schemas.md), and [conformance](../conformance/README.md).
