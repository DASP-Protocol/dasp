# Durable Actor Session Protocol

DASP comes from the Seigyo Protocol in the Jido Core workspace. This project will develop its language-independent specification and maintain its language clients. Elixir and TypeScript are the first targets.

Project home: [DASP Protocol](https://github.com/DASP-Protocol).

## Scope

Only the Seigyo protocol is taken from Jido Code: its specification, schemas, wire fixtures, protocol checks, and existing Elixir client. DASP does not include the Jido Code product, server, runtime, storage, or user interfaces. Jido Code is the source implementation, not a required architecture for DASP hosts.

## Source and status

The [imported Seigyo specification](upstream/seigyo/docs/seigyo/README.md) is the starting point. The import includes the protocol package, an Elixir WebSocket client, JSON schemas, fixed release fixtures, and independent protocol verification scripts.

The source is the local `proj_jido_core/jido_code` repository at commit `ce19eaad40002f0c80e4d71a4c89fea281c7959e`. Its configured remote is `mikehostetler/jido_keel`. This local commit is two commits ahead of the recorded remote branch. See [import provenance](upstream/README.md).

The imported source calls the protocol **Seigyo**. Its current baseline is protocol `1`, profile `coding`, binding `phoenix-channel-websocket`. The broader general-actor contract remains a design target. The DASP name does not change existing Signal types, requirement IDs, version numbers, or contract digests.

The earlier JSON-RPC proposal is [archived](docs/archive/initial-proposal/README.md) and superseded. It was written before the Seigyo source was found and is not the DASP contract.

## Read the documents

- [Specification guide](docs/specification/README.md)
- [Messages and wire format](docs/specification/messages.md)
- [Recovery rules](docs/specification/recovery.md)
- [Client status](clients/README.md)
- [Conformance checks](conformance/README.md)
- [Extraction decisions](docs/design/decisions.md)

`upstream/seigyo/` contains only the selected Seigyo source files, with their original bytes. `reference/agent-host-protocol/` contains the separate Microsoft reference clone. DASP documents explain the source; they do not silently replace its contract.

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
