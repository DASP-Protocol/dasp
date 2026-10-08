# Prepare a DASP specification release

The current preparation target is `0.1.0-draft.1` for core `draft-01`. Preparation creates local artifacts only. A public announcement is a separate activity.

## Prepare

1. Review the [open decisions](docs/project/feedback.md) and coverage gaps.
2. Confirm `specification/release.json`, the project license, and third-party notices.
3. Commit the complete change. The preparation command requires a clean Git tree.
4. Run `npm ci` and `npm run release:prepare`.
5. Inspect `dist/releases/dasp-0.1.0-draft.1/manifest.json`, the coverage report, and archive.
6. Extract the archive into an empty directory and reproduce the documented checks.

The manifest records the source commit and SHA-256 of each source file and saved test report. The archive has a separate SHA-256 file. No network publication occurs in the preparation command.

## Formal release, when authorized

Create an annotated `spec/v0.1.0-draft.1` tag at the reviewed manifest commit. Attach the prepared bundle, manifest, and archive checksum to a GitHub prerelease. Do not regenerate them from a later commit. Add a fixed specification snapshot to the site from that tag and link it from the releases page. Do not call a moving editor's draft a fixed release.

No tag or GitHub release is created by the current documentation workflow. Language packages have independent release versions and must list the exact supported core, profile, and binding.

## Preserve identity

Never move a published release tag. Never replace schema bytes at an existing published identifier. If a correction changes the contract, create a new draft and schema revision where required. Record changes in `CHANGELOG.md`.

## Release checks

- Source and generated site pass `npm run check`.
- Prose, schemas, traces, and coverage agree.
- Runtime gaps and client status are visible.
- The artifact tree contains only public project files.
- A clean extraction reproduces checks.
- Fixed URLs, schema links, canonical URLs, and brand assets work.
- The license and third-party notices accompany the bundle.
