export const pages = {
  'docs/guide/README.md': 'guide/index.md',
  'docs/guide/faq.md': 'guide/faq.md',
  'docs/guide/concepts.md': 'guide/concepts.md',
  'docs/guide/use-cases.md': 'guide/use-cases.md',
  'docs/build/README.md': 'build/index.md',
  'docs/build/walkthrough.md': 'build/walkthrough.md',
  'clients/README.md': 'build/clients.md',
  'clients/elixir/README.md': 'build/elixir.md',
  'clients/typescript/README.md': 'build/typescript.md',
  'docs/specification/README.md': 'specification/index.md',
  'docs/specification/model.md': 'specification/model.md',
  'docs/specification/cloudevents.md': 'specification/cloudevents.md',
  'docs/specification/messages.md': 'specification/messages.md',
  'docs/specification/recovery.md': 'specification/recovery.md',
  'docs/specification/profiles-and-bindings.md': 'specification/profiles-and-bindings.md',
  'docs/specification/security-and-versioning.md': 'specification/security-and-versioning.md',
  'docs/specification/example.md': 'reference/counter.md',
  'conformance/README.md': 'conformance/index.md',
  'conformance/running-checks.md': 'conformance/running-checks.md',
  'conformance/behavioral-cases.md': 'conformance/behavioral-cases.md',
  'docs/reference/README.md': 'reference/index.md',
  'docs/reference/schemas.md': 'reference/schemas.md',
  'docs/reference/examples.md': 'reference/examples.md',
  'docs/reference/recorded-exchange.md': 'reference/recorded-exchange.md',
  'docs/reference/glossary.md': 'reference/glossary.md',
  'docs/project/about.md': 'project/about.md',
  'docs/project/feedback.md': 'project/feedback.md',
  'docs/project/releases.md': 'project/releases.md',
  'CONTRIBUTING.md': 'project/contributing.md',
  'SECURITY.md': 'project/security.md',
  'RELEASING.md': 'project/releasing.md',
  'CHANGELOG.md': 'project/changes.md'
};
export const pageOptions = {
  'docs/build/walkthrough.md': { aside: false, pageClass: 'walkthrough-page' }
};
export const artifacts = {
  'specification/draft-01/envelope.schema.json': 'schemas/draft-01/envelope.schema.json',
  'specification/draft-01/examples/counter.json': 'schemas/draft-01/examples/counter.json',
  'specification/draft-01/examples/counter-profile.schema.json': 'schemas/draft-01/examples/counter-profile.schema.json',
  'specification/artifacts.json': 'schemas/artifacts.json',
  'conformance/fixtures/invalid-events.json': 'fixtures/invalid-events.json',
  'conformance/fixtures/recovery-trace.json': 'fixtures/recovery-trace.json',
  'conformance/requirements.json': 'fixtures/requirements.json',
  'conformance/report-template.json': 'fixtures/report-template.json'
};
// Neutral compatibility pages preserve useful existing URLs without a second source of docs.
export const aliases = {
  'guide.md': 'guide/index.md',
  'protocol/index.md': 'specification/index.md',
  'protocol/cloudevents.md': 'specification/cloudevents.md',
  'protocol/messages.md': 'specification/messages.md',
  'protocol/recovery.md': 'specification/recovery.md',
  'protocol/profiles-and-bindings.md': 'specification/profiles-and-bindings.md',
  'protocol/security-and-versioning.md': 'specification/security-and-versioning.md',
  'protocol/example.md': 'reference/counter.md',
  'clients/index.md': 'build/clients.md',
  'clients/elixir.md': 'build/clients.md#elixir',
  'clients/typescript.md': 'build/clients.md#typescript',
  'project/decisions.md': 'project/feedback.md',
  'source/index.md': 'project/about.md'
};
export const generatedDirectories = ['guide', 'build', 'specification', 'protocol', 'clients', 'conformance', 'reference', 'project', 'source'];
