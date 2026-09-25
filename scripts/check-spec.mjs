import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import Ajv from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { checkTrace } from '../conformance/check-trace.mjs';

const read = path => JSON.parse(readFileSync(path));
const schema = read('specification/draft-01/envelope.schema.json');
const events = read('specification/draft-01/examples/counter.json');
const negatives = read('conformance/fixtures/invalid-events.json');
const trace = read('conformance/fixtures/recovery-trace.json');
const ajv = new Ajv({ strict: true, allErrors: true });
addFormats(ajv);
const validate = ajv.compile(schema);
const results = [];
function check(id, description, fn) { fn(); results.push({ id, description, status: 'passed', scope: 'artifact' }); }
const find = kind => structuredClone(events.find(e => e.type === `dasp.${kind}.v1`));

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
  const updates = events.filter(e => e.type === 'dasp.update.v1');
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
  const profile = read('specification/draft-01/examples/counter-profile.schema.json');
  ajv.addSchema(profile);
  const input = ajv.compile({ $ref: profile.$id + '#/$defs/input' });
  const state = ajv.compile({ $ref: profile.$id + '#/$defs/state' });
  assert(input(find('command').data.input));
  assert(state(find('view').data.state));
  assert(state(find('outcome').data.outcome.output));
  assert.equal(input({ amount: 1000001 }), false);
  assert.equal(input({ amount: 3, text: 'unknown' }), false);
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
check('ART-IDENTITY', 'Previously published schema and example bytes keep their digests', () => {
  for (const [path, expected] of Object.entries(read('specification/artifacts.json').files)) {
    assert.equal(createHash('sha256').update(readFileSync(path)).digest('hex'), expected, path);
  }
});
const report = {
  core: 'draft-01', suite: 'draft-01-artifacts-1',
  scope: 'Recorded artifacts only; no host, client, binding, authorization, or durability execution.',
  counts: { validEvents: events.length, invalidEvents: negatives.length, recordedTraceEvents: trace.steps.length },
  results, runtime: { status: 'not-executed' }
};
mkdirSync('dist', { recursive: true });
writeFileSync('dist/conformance-report.json', JSON.stringify(report, null, 2) + '\n');
console.log(`DASP artifacts: ${events.length} valid events, ${negatives.length} rejected vectors, ${trace.steps.length} recorded trace events. ${results.length} case groups passed. Runtime cases: not executed.`);
