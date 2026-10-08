import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import Ajv from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { checkTrace } from '../conformance/check-trace.mjs';
import { checkLiveTrace } from '../conformance/check-live-trace.mjs';
import { checkEncryptedArtifacts } from '../conformance/check-encrypted-carrier.mjs';
import { checkAuthorityArtifacts } from '../conformance/check-authority.mjs';

const read = path => JSON.parse(readFileSync(path));
const schema = read('specification/draft-01/envelope.schema.json');
const events = read('specification/draft-01/examples/counter.json');
const negatives = read('conformance/fixtures/invalid-events.json');
const trace = read('conformance/fixtures/recovery-trace.json');
const ajv = new Ajv({ strict: true, allErrors: true });
addFormats(ajv);
const validate = ajv.compile(schema);
const counterSchema = read('specification/draft-01/examples/counter-profile.schema.json');
ajv.addSchema(counterSchema);
const capabilityDiscoverySchema = read('specification/draft-01/capability-discovery.schema.json');
const capabilityDiscovery = read('specification/draft-01/examples/capability-discovery.json');
const capabilityDiscoveryFixture = read('conformance/fixtures/capability-discovery.json');
const validateCapabilityDiscovery = ajv.compile(capabilityDiscoverySchema);
const discoveryResourceFiles = new Map([
  ['resource:agent-ask-input', 'specification/draft-01/examples/capability-schemas/agent-ask-input.schema.json'],
  ['resource:allow-any', 'specification/draft-01/examples/capability-schemas/allow-any.schema.json'],
  ['resource:shared-context', 'specification/draft-01/examples/capability-schemas/shared-context.schema.json']
]);
const counterProfile = {
  input: ajv.compile({ $ref: counterSchema.$id + '#/$defs/input' }),
  state: ajv.compile({ $ref: counterSchema.$id + '#/$defs/state' })
};
const results = [];
function check(id, description, fn) { fn(); results.push({ id, description, status: 'passed', scope: 'artifact' }); }
const find = kind => structuredClone(events.find(e => e.type === `dasp.v1.${kind}`));
const discoveryHeader = (operation, kind) => ({
  contract: 'https://dasp-protocol.github.io/dasp/contracts/capability-discovery',
  version: 'draft-01',
  operation,
  kind
});
const capabilityKey = capability => `${capability.profile_uri}\0${capability.profile_version}\0${capability.command}`;
const utf8Compare = (left, right) => Buffer.compare(Buffer.from(left), Buffer.from(right));
const collectSchemaReferences = value => {
  const references = [];
  const visit = current => {
    if (Array.isArray(current)) return current.forEach(visit);
    if (!current || typeof current !== 'object') return;
    for (const [key, child] of Object.entries(current)) {
      if ((key === '$ref' || key === '$dynamicRef') && typeof child === 'string') references.push(child);
      else visit(child);
    }
  };
  visit(value);
  return references;
};
const verifyResource = descriptor => {
  const path = discoveryResourceFiles.get(descriptor.resource);
  assert(path, `Unknown resource descriptor: ${descriptor.resource}`);
  const bytes = readFileSync(path);
  assert.equal(descriptor.media_type, 'application/schema+json');
  assert.equal(bytes.byteLength, descriptor.byte_length, `${descriptor.resource} byte length`);
  assert(descriptor.digest, `${descriptor.resource} digest is required by this example`);
  assert.equal(descriptor.digest.algorithm, 'sha-256');
  assert.equal(descriptor.digest.media_type, descriptor.media_type);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), descriptor.digest.value, `${descriptor.resource} digest`);
  return { bytes, value: JSON.parse(bytes) };
};
const checkManifest = (manifest, limits) => {
  assert.equal(manifest.closed, true);
  const byResource = new Map();
  const bySchemaId = new Map();
  let closureBytes = 0;
  for (const descriptor of manifest.resources) {
    assert(!byResource.has(descriptor.resource), `Duplicate resource: ${descriptor.resource}`);
    byResource.set(descriptor.resource, descriptor);
    if (descriptor.schema_id) {
      assert(!bySchemaId.has(descriptor.schema_id), `Duplicate schema identifier: ${descriptor.schema_id}`);
      bySchemaId.set(descriptor.schema_id, descriptor);
    }
    closureBytes += descriptor.byte_length;
  }
  assert(byResource.has(manifest.input_root), 'Input root is outside the resource closure');
  assert(byResource.has(manifest.output_root), 'Output root is outside the resource closure');
  assert(manifest.resources.length <= limits.closure_resources, 'Resource closure count exceeds the selected limit');
  assert(closureBytes <= limits.closure_bytes, 'Resource closure bytes exceed the selected limit');
  for (const descriptor of manifest.resources) {
    const { value } = verifyResource(descriptor);
    for (const reference of collectSchemaReferences(value)) {
      if (reference.startsWith('#')) continue;
      const resourceId = reference.split('#', 1)[0];
      assert(bySchemaId.has(resourceId), `Reference is outside the closed manifest: ${reference}`);
    }
  }
  const vocabularyUris = manifest.vocabularies.map(item => item.uri);
  assert.equal(new Set(vocabularyUris).size, vocabularyUris.length, 'Duplicate vocabulary identity');
  return { byResource, closureBytes };
};
const checkEnumeration = (pages, profileUniverse, limits) => {
  assert(pages.length > 0, 'Enumeration has no pages');
  const first = pages[0];
  const profileTuple = `${first.profile.uri}\0${first.profile.version}`;
  const summaries = [];
  const pageIds = new Set();
  const continuations = new Set();
  for (const [index, page] of pages.entries()) {
    assert(validateCapabilityDiscovery(page), JSON.stringify(validateCapabilityDiscovery.errors));
    assert.equal(page.actor, first.actor, 'Mixed actor identity');
    assert.deepEqual(page.profile, first.profile, 'Mixed actor profile descriptor');
    assert.equal(page.snapshot, first.snapshot, 'Mixed snapshot identity');
    assert.equal(page.resolved_view, first.resolved_view, 'Mixed resolved-view identity');
    assert(!pageIds.has(page.page), 'Duplicate page identity');
    pageIds.add(page.page);
    assert(page.summaries.length <= limits.page_items, 'Page item limit exceeded');
    assert(Buffer.byteLength(JSON.stringify(page)) <= limits.control_bytes, 'Page control-byte limit exceeded');
    if (index < pages.length - 1) {
      assert.equal(page.complete, false, 'Enumeration completed before its final page');
      assert(page.summaries.length > 0, 'Nonterminal page made no progress');
      assert(page.continuation, 'Nonterminal page has no continuation');
      assert(!continuations.has(page.continuation), 'Continuation loop');
      continuations.add(page.continuation);
    } else {
      assert.equal(page.complete, true, 'Terminal page is not complete');
      assert.equal(page.continuation, undefined, 'Terminal page has a continuation');
    }
    for (const summary of page.summaries) {
      assert.equal(`${summary.capability.profile_uri}\0${summary.capability.profile_version}`, profileTuple, 'Summary profile mismatch');
      const expectedRequirement = profileUniverse.get(summary.capability.command);
      assert(expectedRequirement, `Capability is outside the profile: ${summary.capability.command}`);
      assert.equal(summary.profile_requirement, expectedRequirement, 'Capability requirement mismatch');
      summaries.push(summary);
    }
  }
  const commands = summaries.map(summary => summary.capability.command);
  assert.deepEqual(commands, [...commands].sort(utf8Compare), 'Capability order is not UTF-8 byte order');
  assert.equal(new Set(summaries.map(summary => capabilityKey(summary.capability))).size, summaries.length, 'Duplicate capability identity');
  assert(summaries.length <= limits.view_items, 'Advertised view item limit exceeded');
  assert.deepEqual(new Set(commands), new Set(profileUniverse.keys()), 'Completed enumeration is not the resolved advertised view');
  return summaries;
};
const checkAtomicDetails = (request, reply, profile, advertisedKeys, limits) => {
  assert(validateCapabilityDiscovery(request), JSON.stringify(validateCapabilityDiscovery.errors));
  assert(validateCapabilityDiscovery(reply), JSON.stringify(validateCapabilityDiscovery.errors));
  assert.equal(request.snapshot, reply.snapshot, 'Detail snapshot mismatch');
  assert.deepEqual(reply.profile, profile, 'Detail profile mismatch');
  assert(request.capabilities.length <= limits.detail_items, 'Detail item limit exceeded');
  assert.deepEqual(reply.details.map(item => capabilityKey(item.capability)), request.capabilities.map(capabilityKey), 'Detail response is not atomic and in request order');
  for (const detail of reply.details) {
    assert(advertisedKeys.has(capabilityKey(detail.capability)), 'Detail is outside the advertised snapshot');
    assert.equal(detail.capability.profile_uri, profile.uri, 'Detail profile URI mismatch');
    assert.equal(detail.capability.profile_version, profile.version, 'Detail profile version mismatch');
    checkManifest(detail.schemas, limits);
  }
};

check('ART-SHAPES', 'All 14 core types have valid complete example events', () => {
  for (const event of events) assert(validate(event), JSON.stringify(validate.errors));
  const schemaTypes = schema.oneOf.map(branch => {
    const def = schema.$defs[branch.$ref.split('/').at(-1)];
    return def.properties.type.const;
  });
  assert.deepEqual([...new Set(events.map(e => e.type))].sort(), schemaTypes.sort());
});
check('ART-NEGATIVE', 'Reusable negative vectors fail structural validation', () => {
  assert.equal(new Set(negatives.map(v => v.id)).size, negatives.length);
  for (const vector of negatives) assert.equal(validate(vector.event), false, `Expected rejection: ${vector.id}`);
});
check('ART-EXTENSIONS', 'Optional scalar extensions remain valid', () => {
  const event = find('command');
  Object.assign(event, { subject: event.data.session_id, time: '2026-09-25T12:00:00Z', customflag: true, customcount: 2147483647, customtext: 'example' });
  assert(validate(event), JSON.stringify(validate.errors));
});
check('ART-RELATIONS', 'Counter fixtures preserve replay identity and settlement relationships', () => {
  const updates = events.filter(e => e.type === 'dasp.v1.update');
  const page = find('updates').data;
  assert.deepEqual(updates.map(e => e.data.sequence), [1, 2, 3]);
  assert.deepEqual(page.events, updates.slice(1));
  assert.equal(page.next, page.events.at(-1).data.sequence);
  assert.equal(page.head, 3);
  assert.equal(find('receipt').data.admission_sequence, updates[0].data.sequence);
  assert.deepEqual(find('outcome').data.outcome, updates.at(-1).data.payload);
  assert.equal(find('outcome').data.sequence, updates.at(-1).data.sequence);
  assert.equal(find('view').data.state.value, updates[1].data.payload.data.value);
  assert.equal(find('command').requestid, find('receipt').requestid);
  assert.equal(new Set(events.map(e => e.source + '\0' + e.id)).size, events.length);
});
check('ART-PROFILE', 'Illustrative counter inputs, outputs, and state match its schema', () => {
  const { input, state } = counterProfile;
  assert(input(find('command').data.input));
  assert(state(find('view').data.state));
  assert(state(find('outcome').data.outcome.output));
  assert.equal(input({ amount: 1000001 }), false);
  assert.equal(input({ amount: 3, text: 'unknown' }), false);
});
let discoveryCounts;
check('ART-CAPABILITY-DISCOVERY', 'Progressive discovery controls, exact resources, negative vectors, and 1,000-command paging agree', () => {
  for (const [index, document] of capabilityDiscovery.entries()) {
    assert(validateCapabilityDiscovery(document), `Discovery document ${index}: ${JSON.stringify(validateCapabilityDiscovery.errors)}`);
  }

  const operations = new Set(capabilityDiscovery.map(document => `${document.operation}\0${document.kind}`));
  for (const pair of [
    ['capabilities.list', 'request'],
    ['capabilities.list', 'reply'],
    ['capabilities.get', 'request'],
    ['capabilities.get', 'reply'],
    ['capabilities.resource.read', 'request'],
    ['capabilities.resource.read', 'reply'],
    ['capabilities.snapshot.release', 'request'],
    ['capabilities.snapshot.release', 'reply'],
    ['capabilities.list', 'failure']
  ]) assert(operations.has(pair.join('\0')), `Missing control example: ${pair.join(' ')}`);

  const findDiscovery = (operation, kind) => capabilityDiscovery.filter(document => document.operation === operation && document.kind === kind);
  const start = findDiscovery('capabilities.list', 'request').find(document => document.start);
  const pages = findDiscovery('capabilities.list', 'reply');
  const profileUniverse = new Map([
    ['agent.ask', 'required'],
    ['agent.delegate', 'optional']
  ]);
  const summaries = checkEnumeration(pages, profileUniverse, start.limits);
  const advertisedKeys = new Set(summaries.map(summary => capabilityKey(summary.capability)));
  const continuationRequests = findDiscovery('capabilities.list', 'request').filter(document => document.continuation);
  assert.deepEqual(continuationRequests.map(document => document.continuation), pages.slice(0, -1).map(page => page.continuation));
  assert.deepEqual(structuredClone(pages[0]), pages[0], 'Idempotent first page changed');

  const [detailRequest] = findDiscovery('capabilities.get', 'request');
  const [detailReply] = findDiscovery('capabilities.get', 'reply');
  checkAtomicDetails(detailRequest, detailReply, pages[0].profile, advertisedKeys, start.limits);

  const manifestResources = new Map(detailReply.details[0].schemas.resources.map(item => [item.resource, item]));
  const resourceRequests = findDiscovery('capabilities.resource.read', 'request');
  const resourceReplies = findDiscovery('capabilities.resource.read', 'reply');
  assert.deepEqual(new Set(resourceRequests.map(item => item.resource)), new Set(discoveryResourceFiles.keys()), 'Resource request set is incomplete');
  assert.deepEqual(new Set(resourceReplies.map(item => item.resource.resource)), new Set(discoveryResourceFiles.keys()), 'Resource reply set is incomplete');
  for (const reply of resourceReplies) {
    assert.equal(reply.snapshot, pages[0].snapshot);
    assert.deepEqual(reply.resource, manifestResources.get(reply.resource.resource), 'Resource metadata changed between detail and read');
    verifyResource(reply.resource);
  }

  const inputBytes = readFileSync(discoveryResourceFiles.get('resource:agent-ask-input'));
  const inputSchema = JSON.parse(inputBytes);
  assert.equal(inputSchema.properties.budget.multipleOf, 0.01);
  assert.match(inputBytes.toString(), /"multipleOf": 0\.01/);
  assert.equal(inputSchema.$defs.node.properties.children.items.$dynamicRef, '#node');
  assert.equal(inputSchema['x-example-annotation'], 'This annotation is not part of the JSON Schema vocabulary.');
  assert.equal(inputSchema.$defs.node.$id, 'urn:example:dasp:schema:agent-ask-input:node');
  assert.equal(JSON.parse(readFileSync(discoveryResourceFiles.get('resource:allow-any'))), true);
  assert(detailReply.details[0].schemas.vocabularies.some(item => item.required && item.uri === 'urn:example:dasp:vocabulary:agent-handoff'));

  const failures = [
    'unsupported_contract',
    'invalid_request',
    'unavailable',
    'invalid_continuation',
    'stale_snapshot',
    'request_limit',
    'item_too_large',
    'view_too_large',
    'snapshot_capacity',
    'resource_unavailable',
    'contract_violation'
  ].map(code => ({ ...discoveryHeader('capabilities.list', 'failure'), code }));
  for (const failure of failures) assert(validateCapabilityDiscovery(failure), `${failure.code}: ${JSON.stringify(validateCapabilityDiscovery.errors)}`);
  assert.equal(new Set(failures.map(item => item.code)).size, 11);
  const viewFailure = findDiscovery('capabilities.list', 'failure').find(document => document.code === 'view_too_large');
  assert.equal(viewFailure.limit.name, 'view_items');
  assert(viewFailure.limit.actual > viewFailure.limit.maximum);

  let rejectedVectors = 0;
  const rejectControl = (id, document) => {
    assert.equal(validateCapabilityDiscovery(document), false, `Expected discovery rejection: ${id}`);
    rejectedVectors += 1;
  };
  const rejectFlow = (id, fn) => {
    assert.throws(fn, undefined, id);
    rejectedVectors += 1;
  };
  const withUnknownField = structuredClone(start);
  withUnknownField.internal_target = 'Elixir.Action';
  rejectControl('unknown control field', withUnknownField);
  const changedContinuation = structuredClone(continuationRequests[0]);
  changedContinuation.actor = 'actor:other';
  rejectControl('altered continuation parameters', changedContinuation);
  const emptyNonterminal = structuredClone(pages[0]);
  emptyNonterminal.summaries = [];
  rejectControl('empty continuation page', emptyNonterminal);
  const silentTerminal = structuredClone(pages.at(-1));
  silentTerminal.continuation = 'continuation:after-complete';
  rejectControl('terminal continuation', silentTerminal);
  const unknownFailure = { ...discoveryHeader('capabilities.list', 'failure'), code: 'not_a_failure' };
  rejectControl('unknown failure', unknownFailure);
  const maskedLeakFields = ['actor', 'snapshot', 'resolved_view', 'reason', 'count', 'identity'];
  for (const field of maskedLeakFields) {
    const leaked = { ...discoveryHeader('capabilities.list', 'failure'), code: 'unavailable', [field]: 'secret' };
    rejectControl(`masked unavailable ${field}`, leaked);
  }
  rejectControl('masked unavailable limit', {
    ...discoveryHeader('capabilities.list', 'failure'),
    code: 'unavailable',
    limit: { name: 'control_bytes', maximum: 1 }
  });

  const secondProfile = structuredClone(pages);
  secondProfile[1].profile.version = '2.0.0';
  secondProfile[1].summaries[0].capability.profile_version = '2.0.0';
  rejectFlow('second profile in one snapshot', () => checkEnumeration(secondProfile, profileUniverse, start.limits));
  const outsideProfile = structuredClone(pages);
  outsideProfile[1].summaries[0].capability.command = 'agent.secret';
  rejectFlow('capability outside profile', () => checkEnumeration(outsideProfile, profileUniverse, start.limits));
  const truncated = structuredClone(pages);
  truncated[1].summaries = [];
  rejectFlow('silent complete truncation', () => checkEnumeration(truncated, profileUniverse, start.limits));
  const wrongSnapshot = structuredClone(pages);
  wrongSnapshot[1].snapshot = 'snapshot:agent-42:2';
  rejectFlow('mixed snapshot', () => checkEnumeration(wrongSnapshot, profileUniverse, start.limits));
  const duplicateCapability = structuredClone(pages);
  duplicateCapability[1].summaries[0] = structuredClone(duplicateCapability[0].summaries[0]);
  rejectFlow('duplicate capability identity', () => checkEnumeration(duplicateCapability, profileUniverse, start.limits));
  const oversizedItem = structuredClone(pages);
  oversizedItem[0].summaries[0].description = 'x'.repeat(8192);
  rejectFlow('oversized summary item', () => checkEnumeration(oversizedItem, profileUniverse, { ...start.limits, control_bytes: 1000 }));
  const partialDetails = structuredClone(detailReply);
  partialDetails.details.pop();
  rejectFlow('partial atomic detail response', () => checkAtomicDetails(detailRequest, partialDetails, pages[0].profile, advertisedKeys, start.limits));
  const mixedDetailProfile = structuredClone(detailReply);
  mixedDetailProfile.details[0].capability.profile_version = '2.0.0';
  rejectFlow('detail profile mismatch', () => checkAtomicDetails(detailRequest, mixedDetailProfile, pages[0].profile, advertisedKeys, start.limits));

  const incompleteManifest = structuredClone(detailReply.details[0].schemas);
  incompleteManifest.resources = incompleteManifest.resources.filter(item => item.resource !== 'resource:shared-context');
  rejectFlow('incomplete reference closure', () => checkManifest(incompleteManifest, start.limits));
  const oversizedClosureLimits = { ...start.limits, closure_bytes: 100 };
  rejectFlow('oversized closure', () => checkManifest(detailReply.details[0].schemas, oversizedClosureLimits));
  const badDigest = structuredClone(manifestResources.get('resource:agent-ask-input'));
  badDigest.digest.value = '0'.repeat(64);
  rejectFlow('resource digest mismatch', () => verifyResource(badDigest));
  const badLength = structuredClone(manifestResources.get('resource:agent-ask-input'));
  badLength.byte_length += 1;
  rejectFlow('resource length mismatch', () => verifyResource(badLength));

  const scaleProfile = {
    uri: 'urn:example:dasp:profile:scale',
    version: '1.0.0',
    content_ref: `urn:sha256:${'c'.repeat(64)}`,
    core: {
      id: 'https://dasp-protocol.github.io/dasp/contracts/core',
      version: 'draft-01',
      content_ref: `urn:sha256:${'d'.repeat(64)}`
    }
  };
  const scaleLimits = { ...start.limits, page_items: 100, control_bytes: 1048576 };
  const scaleUniverse = new Map();
  const scaleSummaries = Array.from({ length: 1000 }, (_, index) => {
    const command = `command.${index.toString().padStart(4, '0')}`;
    const profileRequirement = index % 10 === 0 ? 'optional' : 'required';
    scaleUniverse.set(command, profileRequirement);
    return {
      capability: {
        profile_uri: scaleProfile.uri,
        profile_version: scaleProfile.version,
        command
      },
      profile_requirement: profileRequirement
    };
  });
  const scalePages = Array.from({ length: 10 }, (_, index) => ({
    ...discoveryHeader('capabilities.list', 'reply'),
    actor: 'actor:scale',
    profile: scaleProfile,
    snapshot: 'snapshot:scale:1',
    resolved_view: 'view:scale:all',
    page: `page:scale:${index + 1}`,
    summaries: scaleSummaries.slice(index * 100, index * 100 + 100),
    complete: index === 9,
    ...(index === 9 ? {} : { continuation: `continuation:scale:${index + 2}` })
  }));
  const checkedScale = checkEnumeration(scalePages, scaleUniverse, scaleLimits);
  assert.equal(scalePages.length, 10);
  assert.equal(checkedScale.length, 1000);
  assert.equal(scalePages.at(-1).continuation, undefined);
  assert.deepEqual(structuredClone(scalePages[0]), scalePages[0], 'Scale first-page retry changed');

  discoveryCounts = {
    discoveryControlDocuments: capabilityDiscovery.length,
    discoveryRejectedVectors: rejectedVectors,
    discoveryExactResources: discoveryResourceFiles.size,
    discoveryScaleCapabilities: checkedScale.length,
    discoveryScalePages: scalePages.length
  };
});
check('ART-CAPABILITY-DISCOVERY-FIXTURE', 'Shared discovery scale, limit, identity, profile, and resource-stream fixtures agree; no binding or host executed', () => {
  const fixture = capabilityDiscoveryFixture;
  assert.equal(fixture.contract, discoveryHeader('capabilities.list', 'request').contract);
  assert.equal(fixture.version, 'draft-01');
  assert.equal(fixture.status, 'recorded-artifact-only');

  const universe = new Map();
  const summaries = Array.from({ length: fixture.catalog.summary_count }, (_, index) => {
    const command = `${fixture.catalog.command_prefix}${index.toString().padStart(fixture.catalog.command_width, '0')}`;
    const profileRequirement = index % fixture.catalog.optional_every === 0 ? 'optional' : 'required';
    universe.set(command, profileRequirement);
    return {
      capability: {
        profile_uri: fixture.profile.uri,
        profile_version: fixture.profile.version,
        command
      },
      profile_requirement: profileRequirement
    };
  });
  assert.equal(summaries.length, 1000);
  assert.equal(summaries.filter(item => item.profile_requirement === 'required').length, fixture.catalog.required_count);
  assert.equal(summaries.filter(item => item.profile_requirement === 'optional').length, fixture.catalog.optional_count);

  const makePage = (name, index, total, pageSummaries) => ({
    ...discoveryHeader('capabilities.list', 'reply'),
    actor: fixture.actor,
    profile: fixture.profile,
    snapshot: fixture.catalog.snapshot,
    resolved_view: fixture.catalog.resolved_view,
    page: `page:scale:${name}:${String(index + 1).padStart(4, '0')}`,
    summaries: pageSummaries,
    complete: index === total - 1,
    ...(index === total - 1 ? {} : { continuation: `continuation:scale:${name}:${String(index + 2).padStart(4, '0')}` })
  });
  const makePages = (name, pageItems) => {
    const total = Math.ceil(summaries.length / pageItems);
    return Array.from({ length: total }, (_, index) => makePage(name, index, total, summaries.slice(index * pageItems, index * pageItems + pageItems)));
  };
  const checkPageBytes = (pages, scenario) => {
    const sizes = pages.map(page => Buffer.byteLength(JSON.stringify(page)));
    assert(sizes.slice(0, -1).every(size => size === scenario.expected_nonterminal_page_bytes));
    assert.equal(sizes.at(-1), scenario.expected_terminal_page_bytes);
    assert(sizes.every(size => size <= scenario.control_bytes));
  };

  const itemScenario = fixture.paging.item_bound;
  const itemPages = makePages('item', itemScenario.page_items);
  assert.equal(itemPages.length, itemScenario.expected_pages);
  assert.equal(itemPages.filter(page => !page.complete).length, itemScenario.expected_nonterminal_pages);
  assert.equal(checkEnumeration(itemPages, universe, itemScenario).length, 1000);
  checkPageBytes(itemPages, itemScenario);

  const byteScenario = fixture.paging.byte_bound;
  const bytePages = makePages('byte', byteScenario.expected_page_items);
  assert.equal(bytePages.length, byteScenario.expected_pages);
  assert.equal(bytePages.filter(page => !page.complete).length, byteScenario.expected_nonterminal_pages);
  assert.equal(bytePages.at(-1).summaries.length, byteScenario.expected_terminal_items);
  assert.equal(checkEnumeration(bytePages, universe, byteScenario).length, 1000);
  checkPageBytes(bytePages, byteScenario);
  const rejectedCandidate = makePage('byte', 0, byteScenario.expected_pages, summaries.slice(0, byteScenario.rejected_candidate_items));
  assert.equal(Buffer.byteLength(JSON.stringify(rejectedCandidate)), byteScenario.rejected_candidate_bytes);
  assert(byteScenario.rejected_candidate_bytes > byteScenario.control_bytes);

  const detailFixture = fixture.selective_details;
  const detailBatches = [];
  for (let offset = 0; offset < detailFixture.selected_commands.length; offset += detailFixture.batch_items) {
    detailBatches.push(detailFixture.selected_commands.slice(offset, offset + detailFixture.batch_items));
  }
  assert.deepEqual(detailBatches.map(batch => batch.length), detailFixture.expected_batch_sizes);
  assert.equal(detailBatches.length, detailFixture.expected_request_count);
  assert(detailFixture.selected_commands.every(command => universe.has(command)));
  assert.equal(new Set(detailFixture.shared_resources).size, detailFixture.expected_unique_resource_reads);
  assert.equal(detailFixture.expected_unselected_resource_reads, 0);
  assert.deepEqual(fixture.operation_counts, {
    item_bound_list_requests: itemPages.length,
    byte_bound_list_requests: bytePages.length,
    selected_detail_requests: detailBatches.length,
    unique_resource_reads: new Set(detailFixture.shared_resources).size,
    unselected_resource_reads: detailFixture.expected_unselected_resource_reads,
    release_requests: 1
  });

  const startResults = new Map();
  for (let index = 0; index < fixture.idempotency.repeated_start_count; index += 1) {
    if (!startResults.has(fixture.idempotency.start)) {
      startResults.set(fixture.idempotency.start, { snapshot: fixture.catalog.snapshot, page: itemPages[0] });
    }
    assert.equal(startResults.get(fixture.idempotency.start).snapshot, fixture.catalog.snapshot);
    assert.deepEqual(startResults.get(fixture.idempotency.start).page, itemPages[0]);
  }
  assert.equal(new Set([...startResults.values()].map(value => value.snapshot)).size, fixture.idempotency.expected_unique_snapshots);
  assert.equal(new Set([...startResults.values()].map(value => JSON.stringify(value.page))).size, fixture.idempotency.expected_unique_first_pages);

  const capacity = fixture.snapshot_capacity;
  const liveSnapshots = new Set();
  const capacityResults = capacity.start_sequence.map((start, index) => {
    if (liveSnapshots.size >= capacity.live_snapshot_limit) return 'snapshot_capacity';
    const snapshot = `snapshot:capacity:${String.fromCharCode(97 + index)}`;
    liveSnapshots.add(snapshot);
    return snapshot;
  });
  assert.deepEqual(capacityResults, capacity.expected_sequence);
  liveSnapshots.delete(capacity.release);
  liveSnapshots.add(capacity.expected_after_release);
  assert.equal(liveSnapshots.size, capacity.live_snapshot_limit);

  const resource = fixture.resource_stream;
  const resourceBytes = readFileSync(resource.trusted_fixture_file);
  assert.equal(resourceBytes.byteLength, resource.byte_length);
  assert.equal(resource.chunk_bytes.reduce((total, length) => total + length, 0), resource.byte_length);
  const streamDigest = createHash(resource.digest.algorithm);
  let resourceOffset = 0;
  for (const length of resource.chunk_bytes) {
    streamDigest.update(resourceBytes.subarray(resourceOffset, resourceOffset + length));
    resourceOffset += length;
  }
  assert.equal(resourceOffset, resource.byte_length);
  assert.equal(streamDigest.digest('hex'), resource.digest.value);

  const ownership = fixture.ownership;
  const profileCommands = new Map(ownership.profile_universe.map(item => [item.command, item.requirement]));
  const requiredCommands = ownership.profile_universe.filter(item => item.requirement === 'required').map(item => item.command);
  for (const actor of ownership.actors) {
    assert(requiredCommands.every(command => actor.effective.includes(command)));
    assert(actor.effective.every(command => profileCommands.has(command)));
    assert(actor.advertised.every(command => actor.effective.includes(command)));
    assert(!actor.advertised.includes(ownership.forbidden_out_of_profile));
  }

  const unavailableIdentityCases = fixture.identity_cases.filter(item => item.case !== 'valid-expired-same-context');
  assert(unavailableIdentityCases.every(item => item.expected_failure === 'unavailable'));
  assert.equal(fixture.identity_cases.find(item => item.case === 'valid-expired-same-context').expected_failure, 'stale_snapshot');
  assert.equal(fixture.flow_interruptions.disclosure_contraction.expected_failure, 'unavailable');
  assert.equal(fixture.flow_interruptions.disclosure_contraction.discard_incomplete_enumeration, true);
  assert.equal(fixture.flow_interruptions.disclosure_contraction.replacement_snapshot_forbidden, true);
  assert.equal(fixture.flow_interruptions.connection_loss.old_identity_failure, 'unavailable');
  assert.equal(fixture.flow_interruptions.connection_loss.new_enumeration_required, true);
  assert.equal(fixture.flow_interruptions.connection_loss.reuse_old_start_forbidden, true);

  const itemLimit = fixture.limit_failures.item;
  assert(itemLimit.summary_bytes > itemLimit.presentation_bytes);
  assert.equal(itemLimit.expected_failure, 'item_too_large');
  assert.equal(itemLimit.empty_continuation_forbidden, true);
  const viewLimit = fixture.limit_failures.view;
  assert(viewLimit.actual_items > viewLimit.view_items);
  assert.equal(viewLimit.expected_failure, 'view_too_large');
  assert.equal(viewLimit.expected_page_count, 0);
  const closureLimit = fixture.limit_failures.closure;
  let closureResourceReads = 0;
  const readClosure = () => {
    if (closureLimit.declared_bytes > closureLimit.closure_bytes) throw new Error(closureLimit.expected_failure);
    closureResourceReads += 1;
  };
  assert.throws(readClosure, new RegExp(closureLimit.expected_failure));
  assert.equal(closureResourceReads, closureLimit.expected_resource_reads);
  const selectorLimit = fixture.limit_failures.selector;
  let actorLookups = 0;
  const checkSelector = value => {
    if (typeof value !== 'string' || Buffer.byteLength(value) > selectorLimit.opaque_bytes) throw new Error('invalid selector');
    actorLookups += 1;
  };
  assert.throws(() => checkSelector('x'.repeat(selectorLimit.oversized_bytes)), /invalid selector/);
  assert.throws(() => checkSelector({ nested: true }), /invalid selector/);
  assert.equal(actorLookups, selectorLimit.expected_actor_lookups);

  assert.equal(new Set(fixture.unsafe_resource_identities).size, fixture.unsafe_resource_identities.length);
  assert(fixture.unsafe_resource_identities.some(identity => identity.startsWith('https://')));
  assert(fixture.unsafe_resource_identities.some(identity => identity.startsWith('file:')));
  assert(fixture.unsafe_resource_identities.some(identity => identity.includes('../')));

  const profileCases = fixture.profile_cases;
  assert.equal(profileCases.session_assertions[0].profile_uri, fixture.profile.uri);
  assert.equal(profileCases.session_assertions[0].profile_version, fixture.profile.version);
  assert.equal(profileCases.session_assertions[0].expected, 'accepted');
  assert.equal(profileCases.session_assertions[1].expected, 'rejected-before-session');
  assert.notEqual(profileCases.changed_content_ref, fixture.profile.content_ref);
  assert.equal(profileCases.changed_content_ref_expected, 'compatibility-rejected-before-session');
  assert.equal(profileCases.refresh_profile_drift_expected, 'contract_violation');
  assert.equal(new Set(profileCases.sessions.map(session => session.history)).size, profileCases.sessions.length);
  assert.equal(new Set(profileCases.sessions.map(session => session.session)).size, profileCases.sessions.length);

  const interaction = fixture.profile_interaction;
  assert.equal(interaction.thread.session, profileCases.sessions[0].session);
  assert.equal(interaction.thread.history, profileCases.sessions[0].history);
  assert.equal(new Set(interaction.thread.command_ids).size, interaction.thread.command_ids.length);
  assert.deepEqual(interaction.thread.cursor_sequence, [...interaction.thread.cursor_sequence].sort((left, right) => left - right));
  assert.equal(interaction.turns[0].turn_id, null);
  assert.notEqual(interaction.turns[1].turn_id, interaction.turns[1].command_id);
  const child = interaction.child_handoff;
  assert.notEqual(child.parent_actor, child.child_actor);
  assert.notEqual(child.parent_session, child.child_session);
  assert.notEqual(child.parent_snapshot, child.child_snapshot);
  assert.equal(child.shared_authority, false);
  assert.equal(child.shared_history, false);
  assert.equal(child.shared_cursor, false);

  assert(fixture.untrusted_values.some(value => value.includes('<script>')));
  assert(fixture.untrusted_values.some(value => value.includes('$(')));
  assert(fixture.untrusted_values.some(value => value.startsWith('file:')));
  assert(fixture.untrusted_values.some(value => value.startsWith('https://')));
  assert(universe.has(fixture.later_admission.advertised_command));
  assert.equal(fixture.later_admission.expected, 'admission-rejected-without-discovery-violation');
  Object.assign(discoveryCounts, {
    discoveryFixtureItemPages: itemPages.length,
    discoveryFixtureBytePages: bytePages.length,
    discoveryFixtureDetailRequests: detailBatches.length,
    discoveryFixtureResourceReads: detailFixture.expected_unique_resource_reads,
    discoveryFixtureRepeatedStarts: fixture.idempotency.repeated_start_count
  });
});
check('ART-TRACE', 'Recorded lost-receipt, retry, conflict, and two-client replay trace agrees', () => {
  checkTrace(trace, validate);
  // Check that the trace validator rejects meaningful cross-message defects.
  for (const mutate of [
    t => { t.steps.find(s => s.id === 'retry').event.data.input.amount = 4; },
    t => { t.steps.find(s => s.id === 'page-one').event.data.events[0].id = 'changed'; },
    t => { t.steps.find(s => s.id === 'page-two').event.data.events.shift(); },
    t => { t.steps.find(s => s.id === 'duplicate').event.data.admission_sequence = 2; },
    t => { t.clients[1].expected.state.value = 6; }
  ]) {
    const broken = structuredClone(trace); mutate(broken);
    assert.throws(() => checkTrace(broken, validate));
  }
});
let liveCounts;
check('ART-LIVE-TRACE', 'Recorded open, fixed-boundary replay, and resync transcripts agree; no live runtime executed', () => {
  const liveTrace = read('conformance/fixtures/websocket-delivery-traces.json');
  liveCounts = checkLiveTrace(liveTrace, validate, counterProfile);
  const scenario = (trace, id) => trace.scenarios.find(item => item.id === id);
  const receive = (s, kind) => s.steps.find(step => step.action === 'receive' && step.event?.type === `dasp.v1.${kind}`);
  const readRequest = s => s.steps.find(step => step.event?.type === 'dasp.v1.updates.read');
  const reject = (id, mutate, error) => {
    const broken = structuredClone(liveTrace);
    mutate(broken);
    assert.throws(() => checkLiveTrace(broken, validate, counterProfile), error, id);
    liveCounts.liveNegativeVectors = (liveCounts.liveNegativeVectors ?? 0) + 1;
  };
  reject('incorrect captured head', t => { scenario(t, 'reconnect').steps.find(s => s.action === 'handle-open').head = 5; }, /Captured head/);
  reject('incorrect confirmation head', t => { receive(scenario(t, 'reconnect'), 'session.opened').event.data.cursor = 5; }, /Reply differs/);
  reject('new attachment below saved cursor', t => {
    const s = scenario(t, 'reconnect');
    s.initial.cursor = 7;
    s.initial.state = { value: 6 };
    s.steps = s.steps.slice(0, 3);
    // All other conditions pass if the continuity guard is removed.
    s.expected = { cursor: 7, state: { value: 6 }, applied: [], replayReads: 0, discardedReplies: 0, failedReplies: 0, phase: 'live', target: 6, nextPush: 7 };
    t.scenarios = [s];
  }, /Lost continuity/);
  reject('changed saved identity', t => { receive(scenario(t, 'reconnect'), 'updates').event.data.events[0].id = 'changed'; }, /Changed saved identity/);
  reject('missing replay sequence', t => { receive(scenario(t, 'reconnect'), 'updates').event.data.events.shift(); }, /Replay gap/);
  reject('skipped client position', t => { readRequest(scenario(t, 'reconnect')).event.data.after = 4; }, /Read skips/);
  reject('missing first push', t => { const s = scenario(t, 'normal'); s.steps = s.steps.filter(step => step.event?.type !== 'dasp.v1.update' || step.event.data.sequence !== 1); }, /Live delivery gap/);
  reject('missing resync', t => { const s = scenario(t, 'resync'); s.steps = s.steps.filter(step => step.event?.type !== 'dasp.v1.resync.required'); });
  reject('unmatched late failure', t => { receive(scenario(t, 'resync-late-failure-after-confirmation'), 'failure').event.requestid = 'unmatched'; }, /no current request/);
  reject('push before new confirmation', t => {
    const s = scenario(t, 'commit-before-confirmation');
    const i = s.steps.indexOf(receive(s, 'session.opened'));
    [s.steps[i], s.steps[i + 1]] = [s.steps[i + 1], s.steps[i]];
  }, /Push before confirmation/);
  reject('successful conflicting open', t => {
    const s = scenario(t, 'conflicting-open-preserves-stream');
    const reply = receive(s, 'failure').event;
    reply.type = 'dasp.v1.session.opened';
    reply.data = { ...structuredClone(s.steps.find(step => step.event?.requestid === 'conflicting-open' && step.action === 'send').event.data), cursor: 3 };
  }, /Conflicting open confirmed/);
  reject('wrong replay subject', t => { receive(scenario(t, 'reconnect'), 'updates').event.subject = 'different-session'; }, /Wrong session subject/);
  reject('reused outer identity', t => {
    const s = scenario(t, 'reconnect');
    receive(s, 'updates').event.id = receive(s, 'session.opened').event.id;
  }, /Reused outer event identity/);
  reject('invalid selected-profile input', t => { scenario(t, 'normal').steps.find(step => step.event?.type === 'dasp.v1.command').event.data.input.amount = 1000001; }, /Invalid counter command input/);
  reject('second pending open', t => {
    const s = scenario(t, 'reconnect'), second = structuredClone(s.steps[0]);
    second.id = second.event.id = 'second-pending'; second.event.requestid = 'second-pending';
    s.steps.splice(1, 0, second);
  }, /Second pending open/);
  reject('open reply violates resync order', t => {
    const s = scenario(t, 'open-confirmation-before-resync');
    const i = s.steps.findIndex(step => step.event?.requestid === 'equal-before-resync' && step.action === 'receive');
    [s.steps[i], s.steps[i + 1]] = [s.steps[i + 1], s.steps[i]];
  }, /Resync precedes/);
  reject('request on timed-out connection', t => {
    const s = scenario(t, 'open-timeout-closes-connection'), attempt = structuredClone(s.steps[0]);
    attempt.id = attempt.event.id = 'open-after-timeout'; attempt.event.requestid = 'open-after-timeout';
    s.steps.push(attempt);
  }, /Request after connection close/);
});
check('ART-IDENTITY', 'Previously published schema and example bytes keep their digests', () => {
  for (const [path, expected] of Object.entries(read('specification/artifacts.json').files)) {
    assert.equal(createHash('sha256').update(readFileSync(path)).digest('hex'), expected, path);
  }
});
let encryptedCounts;
check('ART-ENCRYPTED-SHAPES', 'Proposed encrypted carrier shapes, encodings, byte bounds, and metadata agree; no cryptography executed', () => {
  encryptedCounts = checkEncryptedArtifacts(ajv, validate);
});
let authorityCounts;
check('ART-AUTHORITY', 'Signed grant vectors, strict bytes, scopes, and recorded admission/budget decisions; no host or binding execution', () => {
  authorityCounts = checkAuthorityArtifacts(ajv, validate, counterProfile);
});
const report = {
  core: 'draft-01', suite: 'draft-01-artifacts-1',
  scope: 'Recorded artifacts and authority signatures with one Node crypto implementation. Capability discovery fixtures are abstract contract evidence only. No discovery binding interoperability, HPKE, host, client, binding, current-permission, concurrent-store, or durability execution.',
  counts: { validEvents: events.length, invalidEvents: negatives.length, recordedTraceEvents: trace.steps.length, ...discoveryCounts, ...liveCounts, ...encryptedCounts, ...authorityCounts },
  results, runtime: { status: 'not-executed' }
};
mkdirSync('dist', { recursive: true });
writeFileSync('dist/conformance-report.json', JSON.stringify(report, null, 2) + '\n');
console.log(`DASP artifacts: ${events.length} valid events, ${negatives.length} rejected vectors, ${trace.steps.length} recorded trace events; ${discoveryCounts.discoveryControlDocuments} discovery controls, ${discoveryCounts.discoveryExactResources} exact schema resources, and ${discoveryCounts.discoveryScaleCapabilities} generated scale capabilities on ${discoveryCounts.discoveryScalePages} pages; ${liveCounts.liveScenarios} live-delivery transcripts with ${liveCounts.liveTraceSteps} steps. ${encryptedCounts.validCarriers} synthetic carrier shapes and ${encryptedCounts.invalidCarriers} rejected carrier vectors; ${encryptedCounts.validProtectedHeaders} valid and ${encryptedCounts.invalidProtectedHeaders} rejected raw headers. ${results.length} case groups passed. Authority: ${authorityCounts.authoritySignedGrants} signed grants, ${authorityCounts.authorityRejectedVectors} rejected vectors, ${authorityCounts.authorityTraceSteps} recorded steps, ${authorityCounts.authorityCommitOrders} serial commit orders. HPKE and runtime cases: not executed.`);
