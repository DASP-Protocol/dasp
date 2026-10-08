import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import {
  DASPError,
  DiscoveryEnumeration,
  DiscoveryResourceVerifier,
  discoveryDocument,
  enumerateCapabilities,
  readDiscoverySchemaClosure,
  validateDiscovery,
  validateDiscoveryDetails,
  validateSchemaManifest,
  verifyDiscoveryResource
} from "../dist/index.js";

const readText = path => readFileSync(new URL(path, import.meta.url));
const read = path => JSON.parse(readText(path));
const documents = read("../../../specification/draft-01/examples/capability-discovery.json");
const fixture = read("../../../conformance/fixtures/capability-discovery.json");
const schemaDirectory = "../../../specification/draft-01/examples/capability-schemas/";
const customVocabulary = "urn:example:dasp:vocabulary:agent-handoff";
const errorCode = expected => error => error instanceof DASPError && error.code === expected;
const limits = () => ({
  page_items: 100,
  view_items: 1000,
  detail_items: 4,
  control_bytes: 1_048_576,
  presentation_bytes: 8192,
  resource_bytes: 1_048_576,
  closure_resources: 16,
  closure_bytes: 4_194_304,
  opaque_bytes: 4096,
  live_snapshots: 2,
  snapshot_retention_ms: 300_000
});

const profile = fixture.profile;
const summary = index => ({
  capability: {
    profile_uri: profile.uri,
    profile_version: profile.version,
    command: fixture.catalog.command_prefix + String(index).padStart(fixture.catalog.command_width, "0")
  },
  profile_requirement: index % fixture.catalog.optional_every === 0 ? "optional" : "required"
});
const scalePages = () => Array.from({ length: 10 }, (_, pageIndex) => {
  const terminal = pageIndex === 9;
  return discoveryDocument("capabilities.list", "reply", {
    actor: fixture.actor,
    profile,
    snapshot: fixture.catalog.snapshot,
    resolved_view: fixture.catalog.resolved_view,
    page: `page:scale:${pageIndex}`,
    summaries: Array.from({ length: 100 }, (_, offset) => summary(pageIndex * 100 + offset)),
    complete: terminal,
    ...(terminal ? {} : { continuation: `next:scale:${pageIndex + 1}` })
  });
});
const startRequest = () => discoveryDocument("capabilities.list", "request", {
  start: fixture.idempotency.start,
  actor: fixture.actor,
  limits: limits()
});
const manifestDocument = () => structuredClone(documents.find(document =>
  document.operation === "capabilities.get" && document.kind === "reply").details[0].schemas);
const resourceBytes = identity => {
  const names = {
    "resource:agent-ask-input": "agent-ask-input.schema.json",
    "resource:allow-any": "allow-any.schema.json",
    "resource:shared-context": "shared-context.schema.json"
  };
  return readText(schemaDirectory + names[identity]);
};
const descriptor = (identity, content, schemaId = "urn:example:root") => ({
  resource: identity,
  media_type: "application/schema+json",
  dialect: "https://json-schema.org/draft/2020-12/schema",
  schema_id: schemaId,
  byte_length: content.byteLength,
  digest: {
    algorithm: "sha-256",
    media_type: "application/schema+json",
    value: createHash("sha256").update(content).digest("hex")
  }
});
const oneResourceManifest = content => ({
  input_root: "resource:test",
  output_root: "resource:test",
  resources: [descriptor("resource:test", content)],
  vocabularies: [],
  closed: true
});

test("validates normative control documents and rejects unknown or duplicate fields", () => {
  for (const document of documents) assert.equal(validateDiscovery(document), document);
  assert.throws(
    () => validateDiscovery({ ...documents[0], authorization: "not part of discovery" }),
    errorCode("invalid_request")
  );
  const duplicate = `{"contract":"${documents[0].contract}","version":"draft-01",` +
    `"operation":"capabilities.snapshot.release","kind":"request","snapshot":"one","snapshot":"two"}`;
  assert.throws(() => validateDiscovery(duplicate), errorCode("invalid_json"));

  const fixed = discoveryDocument("capabilities.snapshot.release", "request", {
    contract: "urn:wrong",
    operation: "capabilities.list",
    kind: "reply",
    snapshot: "snapshot:one"
  });
  assert.equal(fixed.contract, documents[0].contract);
  assert.equal(fixed.operation, "capabilities.snapshot.release");
  assert.equal(fixed.kind, "request");
});

test("reads the shared 1,000-command fixture through a counting carrier", async () => {
  const pages = scalePages();
  let calls = 0, summaries = 0;
  const state = await enumerateCapabilities(startRequest(), async request => {
    const page = pages[calls];
    if (calls > 0) assert.equal(request.continuation, pages[calls - 1].continuation);
    calls++;
    return page;
  }, { onSummary: () => { summaries++; } });
  assert.equal(state.complete, true);
  assert.equal(state.pageCount, fixture.paging.item_bound.expected_pages);
  assert.equal(state.itemCount, fixture.catalog.summary_count);
  assert.equal(state.capabilities.size, 1000);
  assert.deepEqual({ calls, summaries }, { calls: 10, summaries: 1000 });
  assert.throws(() => state.summaries(), errorCode("invalid_request"));
});

test("bounds high-level enumeration with selected and lower local limits", async () => {
  const first = documents[1], terminal = documents[3];
  const exampleStart = structuredClone(documents[0]);
  const selected = structuredClone(exampleStart);
  selected.limits.view_items = 1;
  await assert.rejects(
    () => enumerateCapabilities(selected, async request => "start" in request ? first : terminal),
    errorCode("contract_violation")
  );

  let calls = 0;
  await assert.rejects(
    () => enumerateCapabilities(exampleStart, async () => [first, terminal][calls++], { maxPages: 1 }),
    errorCode("request_limit")
  );
  assert.equal(calls, 2);

  const firstBytes = Buffer.byteLength(JSON.stringify(first));
  calls = 0;
  await assert.rejects(
    () => enumerateCapabilities(exampleStart, async () => [first, terminal][calls++], {
      maxControlBytes: firstBytes
    }),
    errorCode("request_limit")
  );

  const maximum = 2_147_483_647;
  const wideLimits = Object.fromEntries(Object.keys(limits()).map(name => [name, maximum]));
  const wideStart = discoveryDocument("capabilities.list", "request", {
    start: "start:wide",
    actor: fixture.actor,
    limits: wideLimits
  });
  const empty = discoveryDocument("capabilities.list", "reply", {
    actor: fixture.actor,
    profile,
    snapshot: "snapshot:wide",
    resolved_view: "view:wide",
    page: "page:wide",
    summaries: [],
    complete: true
  });
  assert.equal((await enumerateCapabilities(wideStart, async () => empty)).complete, true);
});

test("preserves list failures and binds the first page actor", async () => {
  const failure = discoveryDocument("capabilities.list", "failure", {
    code: "snapshot_capacity",
    limit: { name: "live_snapshots", maximum: 2, actual: 2 }
  });
  await assert.rejects(
    () => enumerateCapabilities(startRequest(), async () => failure),
    error => errorCode("snapshot_capacity")(error) && error.detail.code === failure.code &&
      error.detail.limit.name === failure.limit.name
  );

  const wrongActor = structuredClone(documents[1]);
  wrongActor.actor = "actor:other";
  let callbacks = 0;
  await assert.rejects(
    () => enumerateCapabilities(startRequest(), async () => wrongActor, {
      onPage: () => { callbacks++; },
      onSummary: () => { callbacks++; }
    }),
    errorCode("contract_violation")
  );
  assert.equal(callbacks, 0);
});

test("supports optional accumulation and rejects page context and token errors", () => {
  const first = documents[1], terminal = documents[3];
  const accumulated = new DiscoveryEnumeration({ accumulate: true });
  accumulated.push(first);
  accumulated.push(terminal);
  assert.deepEqual(accumulated.summaries().map(item => item.capability.command), ["agent.ask", "agent.delegate"]);

  const changedProfile = structuredClone(terminal);
  changedProfile.profile.version = "2.0.0";
  const state = new DiscoveryEnumeration();
  state.push(first);
  assert.throws(() => state.push(changedProfile), errorCode("contract_violation"));

  const duplicate = structuredClone(terminal);
  duplicate.summaries = first.summaries;
  assert.throws(() => state.push(duplicate), errorCode("contract_violation"));

  const loop = structuredClone(terminal);
  loop.complete = false;
  loop.continuation = first.continuation;
  assert.throws(() => state.push(loop), errorCode("contract_violation"));

  const boundedView = new DiscoveryEnumeration({ limits: { ...limits(), view_items: 1 } });
  boundedView.push(first);
  assert.throws(() => boundedView.push(terminal), errorCode("contract_violation"));
});

test("keeps enumeration state isolated from callers and callbacks", () => {
  const state = new DiscoveryEnumeration({
    accumulate: true,
    onPage: page => {
      page.complete = true;
      page.profile.version = "changed";
    },
    onSummary: item => { item.capability.command = "changed"; }
  });
  state.push(documents[1]);
  assert.equal(state.complete, false);
  assert.equal(state.profile.version, "1.0.0");
  const exposed = state.capabilities;
  exposed.clear();
  state.push(documents[3]);
  assert.equal(state.capabilities.size, 2);
  const summaries = state.summaries();
  summaries[0].capability.command = "changed";
  assert.equal(state.summaries()[0].capability.command, "agent.ask");
});

test("validates atomic detail identity, order, and closed manifests", () => {
  const enumeration = new DiscoveryEnumeration();
  enumeration.push(documents[1]);
  enumeration.push(documents[3]);
  const request = documents[4], reply = documents[5];
  assert.equal(validateDiscoveryDetails(request, reply, enumeration, {
    supportedVocabularies: [customVocabulary]
  }).length, 2);

  const reversed = structuredClone(reply);
  reversed.details.reverse();
  assert.throws(
    () => validateDiscoveryDetails(request, reversed, enumeration, { supportedVocabularies: [customVocabulary] }),
    errorCode("contract_violation")
  );
  const partial = structuredClone(reply);
  partial.details.pop();
  assert.throws(
    () => validateDiscoveryDetails(request, partial, enumeration, { supportedVocabularies: [customVocabulary] }),
    errorCode("contract_violation")
  );
});

test("enforces selected byte limits before detail work", () => {
  const enumeration = new DiscoveryEnumeration();
  enumeration.push(documents[1]);
  enumeration.push(documents[3]);
  const request = documents[4], reply = documents[5];
  const requestText = JSON.stringify(request), replyText = JSON.stringify(reply);
  const requestBytes = Buffer.byteLength(requestText), replyBytes = Buffer.byteLength(replyText);
  const options = {
    limits: { ...limits(), control_bytes: replyBytes },
    supportedVocabularies: [customVocabulary]
  };
  assert.equal(validateDiscoveryDetails(requestText, replyText, enumeration, options).length, 2);
  assert.throws(
    () => validateDiscoveryDetails(requestText, replyText, enumeration, {
      ...options,
      limits: { ...options.limits, control_bytes: requestBytes - 1 }
    }),
    errorCode("request_limit")
  );
  assert.throws(
    () => validateDiscoveryDetails(request, reply, enumeration, {
      ...options,
      limits: { ...options.limits, control_bytes: replyBytes - 1 }
    }),
    errorCode("contract_violation")
  );
  assert.throws(
    () => validateDiscoveryDetails(request, reply, enumeration, {
      ...options,
      limits: { ...options.limits, opaque_bytes: 1 }
    }),
    errorCode("request_limit")
  );
  assert.throws(
    () => validateDiscoveryDetails(request, reply, enumeration, {
      ...options,
      limits: { ...options.limits, presentation_bytes: 1 }
    }),
    errorCode("contract_violation")
  );
});

test("reads an exact, complete schema closure through an injected carrier", async () => {
  const manifest = validateSchemaManifest(manifestDocument(), {
    limits: limits(),
    supportedVocabularies: [customVocabulary]
  });
  let reads = 0;
  const closure = await readDiscoverySchemaClosure(manifest, async function* (resource) {
    reads++;
    const content = resourceBytes(resource.resource);
    for (let offset = 0; offset < content.byteLength; offset += 127)
      yield content.subarray(offset, Math.min(offset + 127, content.byteLength));
  });
  assert.equal(reads, fixture.selective_details.expected_unique_resource_reads);
  assert.deepEqual([...closure.input], [...resourceBytes("resource:agent-ask-input")]);
  assert.deepEqual([...closure.output], [...resourceBytes("resource:allow-any")]);
  assert.equal(closure.resources.size, 3);
});

test("rejects incomplete references, duplicate schema keys, ids, anchors, and vocabularies", () => {
  assert.throws(() => validateSchemaManifest(manifestDocument()), errorCode("unsupported_vocabulary"));

  const check = (text, expected) => {
    const content = Buffer.from(text);
    const manifest = validateSchemaManifest(oneResourceManifest(content));
    if (expected === "duplicate_json_key")
      assert.throws(() => manifest.putResource("resource:test", content), errorCode(expected));
    else {
      manifest.putResource("resource:test", content);
      assert.throws(() => manifest.finish(), errorCode(expected));
    }
  };
  check('{"$id":"urn:example:root","$ref":"urn:example:missing"}', "unresolved_reference");
  check('{"$id":"urn:example:root","$defs":{"nested":{"$ref":"urn:example:missing"}}}', "unresolved_reference");
  check('{"$id":"urn:example:root","type":"string","type":"number"}', "duplicate_json_key");
  check('{"$id":"urn:example:root","$defs":{"a":{"$id":"urn:example:same"},"b":{"$id":"urn:example:same"}}}', "duplicate_schema_identity");
  check('{"$id":"urn:example:root","$defs":{"a":{"$anchor":"same"},"b":{"$dynamicAnchor":"same"}}}', "duplicate_schema_anchor");
  check('{"$id":"urn:example:root","$defs":{"a/b":{"$id":"urn:example:same"},"a":{"properties":{"b":{"$id":"urn:example:same"}}}}}', "duplicate_schema_identity");
});

test("keeps annotation objects inert and applies a schema-node budget", () => {
  const text = '{"$id":"urn:example:root","default":{"$ref":"urn:example:missing"},' +
    '"examples":[{"$id":"urn:example:duplicate"}],"x-unknown":{"$vocabulary":{"urn:missing":true}}}';
  const content = Buffer.from(text);
  const manifest = validateSchemaManifest(oneResourceManifest(content));
  manifest.putResource("resource:test", content);
  const closure = manifest.finish();
  assert.deepEqual([...closure.resources.get("resource:test")], [...content]);

  const numeric = Buffer.from('{"$id":"urn:example:root","default":[0,1,2]}');
  const bounded = validateSchemaManifest(oneResourceManifest(numeric), { maxSchemaNodes: 5 });
  assert.throws(() => bounded.putResource("resource:test", numeric), errorCode("request_limit"));
});

test("registers boolean resource roots for closed references", () => {
  const input = Buffer.from('{"$id":"urn:example:input","$ref":"urn:example:boolean"}');
  const output = Buffer.from("true");
  const document = {
    input_root: "resource:input",
    output_root: "resource:boolean",
    resources: [
      descriptor("resource:input", input, "urn:example:input"),
      descriptor("resource:boolean", output, "urn:example:boolean")
    ],
    vocabularies: [],
    closed: true
  };
  const manifest = validateSchemaManifest(document);
  manifest.putResource("resource:input", input);
  manifest.putResource("resource:boolean", output);
  const closure = manifest.finish();
  assert.deepEqual([...closure.output], [...output]);
});

test("does not expose mutable manifest or verifier security state", () => {
  const document = manifestDocument();
  const manifest = validateSchemaManifest(document, { supportedVocabularies: [customVocabulary] });
  manifest.supportedVocabularies.add("urn:untrusted:vocabulary");
  manifest.descriptors.clear();
  document.resources.length = 0;
  assert.equal(manifest.descriptors.size, 3);
  assert.equal(manifest.document.resources.length, 3);

  const resource = manifest.document.resources[0];
  const verifier = new DiscoveryResourceVerifier(resource);
  const exposed = verifier.descriptor;
  exposed.byte_length = 0;
  assert.equal(verifier.descriptor.byte_length, resource.byte_length);
});

test("verifies exact bytes incrementally and rejects bad resource metadata", () => {
  const content = resourceBytes(fixture.resource_stream.resource);
  const resource = manifestDocument().resources.find(item => item.resource === fixture.resource_stream.resource);
  const chunks = [];
  let offset = 0;
  for (const size of fixture.resource_stream.chunk_bytes) {
    chunks.push(content.subarray(offset, offset + size));
    offset += size;
  }
  assert.deepEqual(verifyDiscoveryResource(resource, chunks), {
    resource: fixture.resource_stream.resource,
    byteLength: fixture.resource_stream.byte_length,
    sha256: fixture.resource_stream.digest.value
  });
  assert.throws(
    () => verifyDiscoveryResource({ ...resource, byte_length: resource.byte_length + 1 }, chunks),
    errorCode("length_mismatch")
  );
  assert.throws(
    () => verifyDiscoveryResource({ ...resource, digest: { ...resource.digest, value: "0".repeat(64) } }, chunks),
    errorCode("digest_mismatch")
  );
  assert.throws(
    () => new DiscoveryResourceVerifier({ ...resource, digest: { ...resource.digest, algorithm: "sha-512" } }),
    errorCode("unsupported_digest")
  );
  for (const identity of fixture.unsafe_resource_identities)
    assert.throws(() => new DiscoveryResourceVerifier({ ...resource, resource: identity }), errorCode("unsafe_identity"));
});

test("keeps discovery outside the unchanged 14 core event types", () => {
  const envelope = read("../schema/envelope.schema.json");
  const core = [
    "session.open", "session.opened", "command", "receipt", "update", "progress", "view.read", "view",
    "updates.read", "updates", "outcome.read", "outcome", "resync.required", "failure"
  ];
  assert.equal(envelope.oneOf.length, 14);
  assert.deepEqual(envelope.oneOf.map(item => item.$ref), core.map(kind => `#/$defs/${kind}Event`));
  assert.equal(envelope.oneOf.some(item => /capabilit|thread|turn/.test(item.$ref)), false);
});
