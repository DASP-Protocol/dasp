# Extraction decisions

DASP starts from Jido Seigyo. The imported contract takes precedence over the initial independent proposal.

| Area | Source rule to preserve |
| --- | --- |
| Transport | Phoenix Channel WebSocket frames with Signals |
| Command lifecycle | Admission Receipt is separate from outcome |
| Recovery | Contiguous saved Updates and applied cursors |
| Identity | Typed IDs; preserve retry scope and equality rules |
| Portable data | Closed schemas, safe JSON integers, explicit limits |
| Commit authority | Session Store and Agent checkpoint are separate |
| Profiles | Common semantics plus profile-specific schemas |
| Release | Immutable bundle and separate source provenance |

## Next extraction work

1. Define the DASP common profile from the source's common semantics. Keep coding-specific fields in the coding profile.
2. Decide whether DASP retains the existing wire names or introduces a new version. Do not rename them during import.
3. Establish language-independent ownership of schemas and validation rules. Keep custom rules and negative vectors with the schemas.
4. Extract the existing Elixir client into this project's release structure. Replace workspace-relative dependencies with reviewed package dependencies.
5. Implement the TypeScript client against the same published frames and vectors.
6. Define external authentication, deployment limits, package names, and project licensing before a public release.

Only the selected protocol source remains unchanged under `upstream/seigyo/`. The active guides do not promote proposed Work, general-agent, or collaboration features into current coding v1 requirements.

## Project boundary

Jido Code is the source of Seigyo, not the product being imported. DASP owns the protocol specification, shared conformance material, and language clients. Host runtimes, storage engines, agent execution, and user interfaces are separate implementations.
