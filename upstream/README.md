# Seigyo source import

Source workspace: `/Users/mhostetler/Source/Jido/proj_jido_core/jido_code`.

Configured remote: [mikehostetler/jido_keel](https://github.com/mikehostetler/jido_keel).

Imported commit: `ce19eaad40002f0c80e4d71a4c89fea281c7959e`.

The source working tree was clean. Local `main` was two commits ahead of its recorded `origin/main`. This import uses the local committed source, not a claim about the current remote branch. No upstream files were changed.

Only the Seigyo protocol subset is retained in `seigyo/`:

- Protocol documents and related design decisions.
- The `jido_seigyo` data schemas, release fixtures, Elixir client, and package tests.
- Independent Python protocol verification scripts and their portable tests.

Jido Code server, runtime, storage, database, UI, evaluation, deployment, and server-dependent acceptance code are excluded. Original source paths remain inside this subset to show provenance. The `apps/jido_code_acceptance/scripts/` directory contains only independent protocol tools; it is not the acceptance application.

The [manifest](seigyo-import.json) records the source revision, import scope, and SHA-256 hash of each retained file. Retained files are unchanged. Some source notes refer to Jido Code components outside this import; those references describe the original implementation and do not add DASP dependencies.

## Main paths

- [Protocol documents](seigyo/docs/seigyo/README.md)
- [Protocol package and Elixir client](seigyo/apps/jido_seigyo/README.md)
- [Frozen coding v1 contract](seigyo/apps/jido_seigyo/priv/seigyo/coding-v1/contract.json)
- [Initialization schemas](seigyo/apps/jido_seigyo/priv/seigyo/initialization-v1/schemas.json)
- [Replay vectors](seigyo/apps/jido_seigyo/priv/seigyo/replay-v1/vectors.json)
- [Contract verifier](seigyo/apps/jido_code_acceptance/scripts/verify_contract.py)

The frozen contract digest is `772c344d263f7cf35ba49c01040832192e75324001e75ad5409f57ae78aacb56`. Its own provenance identifies an earlier baseline revision. The snapshot revision and the frozen contract revision have different purposes; both remain unchanged.

No tracked LICENSE or NOTICE file was found at this source revision. Existing source notices remain unchanged. This import does not assign a license to the source.

The imported Elixir protocol package still uses its original umbrella and sibling dependency paths. Package extraction remains separate work. No Jido Code server is included or required as part of the protocol specification. The Python contract check runs without those dependencies.

Do not edit the imported files in place. Make DASP extraction changes outside this tree and record their compatibility effect. A future source update must record a new revision and file manifest, and pass the frozen contract check.
