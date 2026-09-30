import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import Ajv from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { checkTrace } from '../conformance/check-trace.mjs';
import { checkLiveTrace } from '../conformance/check-live-trace.mjs';
import { checkEncryptedArtifacts } from '../conformance/check-encrypted-carrier.mjs';

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
const counterProfile = {
  input: ajv.compile({ $ref: counterSchema.$id + '#/$defs/input' }),
  state: ajv.compile({ $ref: counterSchema.$id + '#/$defs/state' })
};
const results = [];
function check(id, description, fn) { fn(); results.push({ id, description, status: 'passed', scope: 'artifact' }); }
const find = kind => structuredClone(events.find(e => e.type === `dasp.v1.${kind}`));

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
const report = {
  core: 'draft-01', suite: 'draft-01-artifacts-1',
  scope: 'Recorded artifacts only; no cryptographic, host, client, binding, authorization, or durability execution.',
  counts: { validEvents: events.length, invalidEvents: negatives.length, recordedTraceEvents: trace.steps.length, ...liveCounts, ...encryptedCounts },
  results, runtime: { status: 'not-executed' }
};
mkdirSync('dist', { recursive: true });
writeFileSync('dist/conformance-report.json', JSON.stringify(report, null, 2) + '\n');
console.log(`DASP artifacts: ${events.length} valid events, ${negatives.length} rejected vectors, ${trace.steps.length} recorded trace events; ${liveCounts.liveScenarios} live-delivery transcripts with ${liveCounts.liveTraceSteps} steps. ${encryptedCounts.validCarriers} synthetic carrier shapes and ${encryptedCounts.invalidCarriers} rejected carrier vectors; ${encryptedCounts.validProtectedHeaders} valid and ${encryptedCounts.invalidProtectedHeaders} rejected raw headers. ${results.length} case groups passed. Cryptography and runtime cases: not executed.`);
