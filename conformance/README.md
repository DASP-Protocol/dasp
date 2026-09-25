# Conformance

## DASP draft checks

Run `npm run spec:check`. It validates the generic CloudEvents message schema against 16 example events and 18 invalid shapes. It also checks replay event identity, receipt correlation, saved outcome equality, and example cursor consistency.

These checks validate draft artifacts. They do not execute a host, prove concurrency safety, test authorization, or establish restart durability. The checker does not yet enforce raw JSON duplicate-key detection, all CloudEvents Unicode constraints, encoded-byte limits, or runtime profile behavior.

Before a release, add binding and profile fixtures plus behavioral fault checks for concurrent retries, lost receipts, command-ID conflicts across sessions, uncertain effects, immutable settlement, replay gaps, access revocation, and process restart.

## Source reference checks

The import includes the Seigyo frozen release bundle, Python checker, schema and frame vectors, and independent protocol verification scripts. These replace the initial hypothetical test plan.

From the DASP root, verify the frozen bundle:

```sh
python3 upstream/seigyo/apps/jido_code_acceptance/scripts/verify_contract.py upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1 --digest 772c344d263f7cf35ba49c01040832192e75324001e75ad5409f57ae78aacb56
```

Run the imported portable verifier tests:

```sh
SEIGYO_CONTRACT="$PWD/upstream/seigyo/apps/jido_seigyo/priv/seigyo/coding-v1" PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s upstream/seigyo/apps/jido_code_acceptance/scripts -p 'test_*.py'
```

These checks do not require a running Elixir server. They do not establish live server conformance. See the [source conformance rules](../upstream/seigyo/docs/seigyo/conformance.md) and [verification guide](../upstream/seigyo/docs/seigyo/verification.md) for that separate test scope.

The source snapshot manifest is checked by `python3 scripts/verify_import.py`. It checks every imported file against its recorded hash and reports extra files. Frozen bundle verification checks the separate normative contract digest.

## Import check results

The import check verified 179 protocol source files. The frozen coding v1 digest check passed. All 21 portable Python tests passed. Elixir compilation and live endpoint acceptance tests were not run.
