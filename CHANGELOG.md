# Changes

## Unreleased — review preparation

- Base the Elixir client on Jido Signal 2.3. Return signals from client calls and pass signals to profile validators and reducers. Preserve the DASP wire format with an explicit codec.
- Keep TypeScript's Node type definitions on the minimum supported Node 22 version.

- Add experimental Elixir and TypeScript client packages for draft-01 with transport adapters, strict decoding, reply checks, and checkpoint recovery.
- Test both packages against shared draft vectors and recorded recovery cases. Check standalone archive installation.
- Add client CI across supported runtimes and weekly Dependabot updates for npm, Mix, and GitHub Actions.
- Add package usage guides and recorded adapter examples.
- Define DASP through a guide, builder paths, normative core, conformance coverage, and technical reference.
- Keep public project content separate from local research and tools.
- Add recorded recovery examples, reusable negative vectors, requirement references, and runtime case definitions.
- Add source and built-site publication checks and local release bundle preparation.
- Preserve the existing draft-01 schema and example bytes.

No host, client, or transport interoperability release is claimed.
