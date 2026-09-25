# Durable Actor Session Protocol

DASP comes from the Seigyo Protocol in the Jido Core workspace. This project will develop its language-independent specification and maintain its language clients. Elixir and TypeScript are the first targets.

Project home: [DASP Protocol](https://github.com/DASP-Protocol).

## Scope

Only the Seigyo protocol is taken from Jido Code: its specification, schemas, wire fixtures, protocol checks, and existing Elixir client. DASP does not include the Jido Code product, server, runtime, storage, or user interfaces. Jido Code is the source implementation, not a required architecture for DASP hosts.

## Active specification

[DASP draft-01](docs/specification/README.md) defines a standalone, generic actor-session protocol based on CloudEvents 1.0. Application profiles supply domain data. Transport bindings supply connection and routing behavior.

The draft includes [generic schemas and example events](specification/draft-01/). Run `npm run spec:check` for structural checks. It is not a released interoperability contract. The first production binding, profile, host, and DASP clients remain to be implemented.

## Source and compatibility

The Seigyo specification and client are imported as immutable reference material. DASP preserves their useful admission, retry, replay, and uncertainty semantics, but defines its own generic shapes. The imported coding contract does not take precedence over the active DASP draft.

See the [source mapping](docs/design/seigyo-mapping.md) for deliberate differences and adapter requirements, and [import provenance](upstream/README.md) for source identity. The imported Elixir client does not implement DASP draft-01. Archived proposals are not active specifications.

## Read the documents

- [Specification guide](docs/specification/README.md)
- [Messages and wire format](docs/specification/messages.md)
- [Recovery rules](docs/specification/recovery.md)
- [Client status](clients/README.md)
- [Conformance checks](conformance/README.md)
- [Extraction decisions](docs/design/decisions.md)

`upstream/seigyo/` contains only the selected Seigyo source files, with their original bytes. `reference/agent-host-protocol/` contains the separate Microsoft reference clone. DASP defines a separate draft contract. The reference imports retain their original meaning and bytes.

## Brand assets

See the [brand guide](website/brand.md) for logos, icons, social previews, and use rules. Run `npm run brand:build` to rebuild all assets from the shared vector source.

## Documentation website

The design preview is published at [dasp-protocol.github.io/dasp](https://dasp-protocol.github.io/dasp/).

```sh
npm ci
npm run docs:dev
```

Run `npm run docs:build` for the production site. Run `npm run docs:preview` to inspect that build locally.

VitePress builds the site from `website/`. The landing page and introduction are authored there. `scripts/build-docs.mjs` generates the protocol, client, and project pages from this repository's Markdown documents. Edit the original documents; generated pages are excluded from Git. Source-only links point to GitHub.

The `Documentation` workflow checks the Seigyo import and portable protocol tests, then builds the site. A successful `main` build deploys to GitHub Pages. Pull requests build without deployment. Vite is pinned to a patched 6.x release through an npm override while VitePress 1.x retains its older dependency range.
