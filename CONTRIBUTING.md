# Contributing to DASP

Start with the [guide](docs/guide/README.md) and [active specification](docs/specification/README.md). Changes must preserve the distinction between core requirements, profile behavior, transport bindings, and implementation choices.

## Propose a change

Open an issue with the draft version, source commit, affected requirement or message, an example, and expected behavior. Keep proposals separate from current requirements until they are accepted.

A protocol change needs:

- Language-independent prose with a stable requirement ID.
- Matching schemas or documented custom validation rules.
- Valid and invalid examples.
- A conformance case and accurate coverage status.
- A compatibility note when behavior or structure changes.

Keep the existing requirement IDs stable. Use BCP 14 uppercase terms only for normative requirements. Describe the responsible party, trigger, and observable result. A `SHOULD` needs a reason and an allowed exception.

## Check the change

```sh
npm ci
npm run check
```

Edit authored files in `docs/`, not generated website pages. Keep local research, plans, skills, and tool files outside the repository. Do not change the bytes at an existing published schema identifier.

Elixir and TypeScript clients must target the same selected core, profile, and binding. A package version is not a protocol version. Do not claim runtime conformance from example validation.

## Review and release

Maintainers review scope, compatibility, examples, and test evidence in pull requests. Record deferred choices on the review page. The [release checklist](RELEASING.md) defines artifact preparation. Report security concerns through [SECURITY.md](SECURITY.md).
