export const pages = {
  'docs/guide/README.md': 'guide/index.md',
  'docs/guide/faq.md': 'guide/comparisons.md',
  'docs/guide/cloudevents.md': 'guide/cloudevents.md',
  'docs/build/host.md': 'build/host.md',
  'docs/build/profiles-and-bindings.md': 'build/profiles-and-bindings.md',
  'docs/build/README.md': 'build/index.md',
  'docs/build/walkthrough.md': 'guide/walkthrough.md',
  'clients/README.md': 'build/clients.md',
  'clients/elixir/README.md': 'build/elixir.md',
  'clients/typescript/README.md': 'build/typescript.md',
  'docs/specification/README.md': 'specification/index.md',
  'docs/specification/model.md': 'specification/model.md',
  'docs/specification/cloudevents.md': 'specification/cloudevents.md',
  'docs/specification/messages.md': 'specification/messages.md',
  'docs/specification/recovery.md': 'specification/recovery.md',
  'docs/specification/profiles-and-bindings.md': 'specification/profiles-and-bindings.md',
  'docs/specification/websocket-live-delivery.md': 'specification/websocket-live-delivery.md',
  'docs/specification/security-and-versioning.md': 'specification/security-and-versioning.md',
  'docs/specification/payload-encryption.md': 'specification/payload-encryption.md',
  'docs/specification/example.md': 'reference/counter.md',
  'conformance/README.md': 'specification/conformance/index.md',
  'conformance/running-checks.md': 'specification/conformance/running-checks.md',
  'conformance/behavioral-cases.md': 'specification/conformance/behavioral-cases.md',
  'docs/reference/README.md': 'reference/index.md',
  'docs/reference/schemas.md': 'reference/schemas.md',
  'docs/reference/examples.md': 'reference/examples.md',
  'docs/reference/glossary.md': 'reference/glossary.md',
  'docs/project/about.md': 'about/index.md',
  'docs/project/feedback.md': 'about/status.md',
  'CONTRIBUTING.md': 'about/contributing.md',
  'SECURITY.md': 'about/security.md',
  'RELEASING.md': 'about/releasing.md',
  'CHANGELOG.md': 'about/changes.md'
};
export const pageOptions = {
  'docs/build/walkthrough.md': { aside: false, pageClass: 'walkthrough-page' }
};
export const artifacts = {
  'specification/draft-01/envelope.schema.json': 'schemas/draft-01/envelope.schema.json',
  'specification/draft-01/bindings/encrypted-carrier.schema.json': 'schemas/draft-01/bindings/encrypted-carrier.schema.json',
  'specification/draft-01/examples/counter.json': 'schemas/draft-01/examples/counter.json',
  'specification/draft-01/examples/counter-profile.schema.json': 'schemas/draft-01/examples/counter-profile.schema.json',
  'specification/artifacts.json': 'schemas/artifacts.json',
  'conformance/fixtures/invalid-events.json': 'fixtures/invalid-events.json',
  'conformance/fixtures/encrypted-carriers.json': 'fixtures/encrypted-carriers.json',
  'conformance/fixtures/encrypted-header-vectors.json': 'fixtures/encrypted-header-vectors.json',
  'conformance/fixtures/recovery-trace.json': 'fixtures/recovery-trace.json',
  'conformance/fixtures/websocket-delivery-traces.json': 'fixtures/websocket-delivery-traces.json',
  'conformance/requirements.json': 'fixtures/requirements.json',
  'conformance/report-template.json': 'fixtures/report-template.json'
};
// Neutral compatibility pages preserve useful existing URLs without a second source of docs.
export const aliases = {
  'guide.md': 'guide/index.md',
  'guide/faq.md': 'guide/comparisons.md',
  'guide/concepts.md': 'reference/glossary.md',
  'guide/use-cases.md': 'guide/index.md#where-it-fits',
  'build/walkthrough.md': 'guide/walkthrough.md',
  'reference/recorded-exchange.md': 'reference/examples.md',
  'conformance/index.md': 'specification/conformance/index.md',
  'conformance/running-checks.md': 'specification/conformance/running-checks.md',
  'conformance/behavioral-cases.md': 'specification/conformance/behavioral-cases.md',
  'protocol/index.md': 'specification/index.md',
  'protocol/cloudevents.md': 'specification/cloudevents.md',
  'protocol/messages.md': 'specification/messages.md',
  'protocol/recovery.md': 'specification/recovery.md',
  'protocol/profiles-and-bindings.md': 'specification/profiles-and-bindings.md',
  'protocol/security-and-versioning.md': 'specification/security-and-versioning.md',
  'protocol/example.md': 'reference/counter.md',
  'clients/index.md': 'build/clients.md',
  'clients/elixir.md': 'build/elixir.md',
  'clients/typescript.md': 'build/typescript.md',
  'project/about.md': 'about/index.md',
  'project/feedback.md': 'about/status.md',
  'project/decisions.md': 'about/status.md',
  'project/contributing.md': 'about/contributing.md',
  'project/security.md': 'about/security.md',
  'project/changes.md': 'about/changes.md',
  'project/releases.md': 'about/releasing.md',
  'project/releasing.md': 'about/releasing.md',
  'source/index.md': 'about/index.md'
};
// Retired source pages keep one canonical destination for generated links.
export const sourceRedirects = {
  'docs/guide/concepts.md': 'docs/reference/glossary.md',
  'docs/guide/use-cases.md': 'docs/guide/README.md',
  'docs/reference/recorded-exchange.md': 'docs/reference/examples.md',
  'docs/project/releases.md': 'RELEASING.md'
};
export const generatedDirectories = ['guide', 'build', 'specification', 'protocol', 'clients', 'conformance', 'reference', 'project', 'source', 'about'];
