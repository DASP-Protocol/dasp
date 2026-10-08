import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { setImmediate as tick } from 'node:timers/promises';
import { Client, LiveRecovery, DuplexTransport, applyUpdates, checkpointFromView } from '../dist/index.js';
const fixture = JSON.parse(readFileSync(new URL('../../../conformance/fixtures/websocket-delivery-traces.json', import.meta.url)));
const host = 'urn:example:host:one', source = 'urn:example:client:one';
const profile = () => true;
const reduce = (state, event) => event.data.kind === 'application' ? event.data.payload.data : state;
const envelope = (kind, data, requestid = 'request') => ({ specversion: '1.0', id: crypto.randomUUID(),
  source: kind.endsWith('.read') || kind === 'session.open' ? source : host,
  type: 'dasp.v1.' + kind, datacontenttype: 'application/json', requestid, data });
const json = JSON.stringify;
const initial = (cursor = 0) => applyUpdates(checkpointFromView(envelope('view',
  { ...fixture.session, cursor: 0, state: { value: 0 } }), profile), fixture.saved.slice(0, cursor), reduce, profile);
const start = (cursor = 0, extra = {}) => new LiveRecovery({ checkpoint: initial(cursor), clientSource: source,
  reduce, validateProfile: profile, ...extra });
const open = (live, head, id = 'open') => live.sent(json(envelope('session.open', fixture.session, id)))
  .received(json(envelope('session.opened', { ...fixture.session, cursor: head }, id)));
const code = value => e => e.code === value;

for (const scenario of fixture.scenarios) test('live state executes recorded scenario ' + scenario.id, () => {
  let live = start(scenario.initial.cursor), discarded = 0;
  assert.deepEqual(live.checkpoint.state, scenario.initial.state);
  for (const step of scenario.steps) {
    if (step.action === 'send') live = live.sent(json(step.event), { replay: step.event.type === 'dasp.v1.updates.read' });
    else if (step.action === 'receive') {
      live = live.received(json(step.event));
      if (live.action === 'discard') discarded++;
    } else if (step.action === 'close') live = live.close();
    else if (step.action === 'open-timeout') live = live.timeout(live.pendingOpen);
  }
  assert.equal(live.checkpoint.cursor, scenario.expected.cursor);
  assert.deepEqual(live.checkpoint.state, scenario.expected.state);
  assert.equal(live.phase, scenario.expected.phase);
  assert.equal(live.target, scenario.expected.target);
  assert.equal(discarded, scenario.expected.discardedReplies);
});

test('new attachment rejects a lower head, retained attachment keeps its boundary', () => {
  assert.throws(() => open(start(3), 2), code('continuity'));
  let live = open(start(3), 3);
  live = live.sent(json(envelope('session.open', fixture.session, 'repeat')));
  live = live.received(json(fixture.saved[3]));
  const next = live.received(json(envelope('session.opened', { ...fixture.session, cursor: 3 }, 'repeat')));
  assert.equal(next.checkpoint.cursor, 4); assert.equal(next.target, 3); assert.equal(next.phase, 'live');
});
test('one pending open and request-ID uniqueness are enforced', () => {
  const live = start().sent(json(envelope('session.open', fixture.session, 'one')));
  assert.throws(() => live.sent(json(envelope('session.open', fixture.session, 'two'))), code('live'));
  assert.throws(() => live.sent(json(envelope('session.open', fixture.session, 'one'))), code('correlation'));
  assert.equal(live.timeout('one').phase, 'closed');
});
test('bounded buffering and gaps fail without changing the previous checkpoint', () => {
  const live = open(start(), 1);
  assert.throws(() => live.received(json(fixture.saved[2])), code('gap'));
  const bounded = open(start(3, { maxBufferedEvents: 1 }), 4);
  const first = bounded.received(json(fixture.saved[4]));
  assert.throws(() => first.received(json(fixture.saved[5])), code('overflow'));
  const bytes = open(start(3, { maxBufferedBytes: 1 }), 4);
  assert.throws(() => bytes.received(json(fixture.saved[4])), code('overflow'));
  assert.equal(first.checkpoint.cursor, 3); assert.equal(bounded.checkpoint.cursor, 3);
});
test('ordinary reads do not create replay or move the applied cursor', () => {
  const live = open(start(), 0);
  const tracked = live.sent(json(envelope('updates.read', { session_id: fixture.session.session_id, after: 0, limit: 1 }, 'read')));
  const next = tracked.received(json(envelope('updates', { session_id: fixture.session.session_id, after: 0,
    next: 1, head: 1, events: [fixture.saved[0]] }, 'read')));
  assert.equal(next.checkpoint.cursor, 0); assert.equal(next.nextRead(), null);
});
test('reducer failure preserves the original recovery state', () => {
  const live = open(start(0, { reduce: () => { throw new Error('failed'); } }), 0);
  assert.throws(() => live.received(json(fixture.saved[0])), /failed/);
  assert.equal(live.checkpoint.cursor, 0);
  const copy = live.checkpoint; copy.state.value = 999;
  assert.equal(live.checkpoint.state.value, 0);
});

async function sent(wires, count) {
  for (let i = 0; i < 50 && wires.length < count; i++) await tick();
  assert.equal(wires.length, count);
  return JSON.parse(wires[count - 1]);
}
const client = transport => new Client({ source, hostSource: host, transport, validateProfile: profile, timeoutMs: 1000 });

test('immediate completion is applied before the command receipt arrives', async () => {
  let live = start(), saved = initial(), resolved = false;
  const wires = [], incoming = [], checkpoints = [];
  const duplex = new DuplexTransport({ hostSource: host, close() {}, send: wire => {
    const q = JSON.parse(wire); wires.push(wire);
    // The in-memory peer responds during send, before a caller can await its reply.
    if (q.type === 'dasp.v1.session.open') {
      incoming.push(duplex.receive(json(envelope('session.opened', { ...fixture.session, cursor: 0 }, q.requestid))));
    } else if (q.type === 'dasp.v1.command') {
      for (const event of fixture.saved.slice(0, 3)) {
        incoming.push(duplex.receive(json({ ...event, requestid: q.requestid })));
      }
    }
  }, onEvent: n => {
    if (n.kind === 'closed') { live = live.close(); return; }
    if (n.kind === 'timeout') { live = live.timeout(n.requestid); return; }
    live = n.kind === 'sent' ? live.sent(n.wire) : live.received(n.wire);
    if (live.action === 'save') { saved = live.checkpoint; checkpoints.push(saved); }
  } });
  const c = client(duplex.transport);
  await c.open(fixture.session);
  const pending = c.submit(fixture.session, { command_id: fixture.saved[0].data.command_id,
    name: 'counter.add', input: { amount: 3 } }).then(reply => { resolved = true; return reply; });
  const q = await sent(wires, 2);
  await Promise.all(incoming);
  assert.equal(resolved, false, 'Saved pushes must not resolve the command receipt');
  assert.deepEqual(checkpoints.map(cp => cp.cursor), [1, 2, 3]);
  assert.deepEqual(saved, initial(3), 'State, cursor, and evidence cover immediate completion');
  assert.equal(live.phase, 'live'); assert.equal(live.nextRead(), null);
  await duplex.receive(json(envelope('receipt', { session_id: fixture.session.session_id,
    command_id: q.data.command_id, disposition: 'accepted', admission_sequence: 1, error: null }, q.requestid)));
  assert.equal((await pending).data.admission_sequence, 1);
  assert.equal(checkpoints.length, 3, 'A receipt does not apply another fact');
  assert.deepEqual(live.checkpoint, saved);
  duplex.close();
});

test('duplex dispatches out-of-order replies and pushes with request IDs', async () => {
  const wires = [], notices = [];
  const duplex = new DuplexTransport({ hostSource: host, send: w => { wires.push(w); }, close() {}, onEvent: n => { notices.push(n); } });
  const c = client(duplex.transport);
  const one = c.readView(fixture.session), two = c.readOutcome(fixture.session, 'cmd');
  await sent(wires, 2);
  const [q1, q2] = wires.map(JSON.parse);
  await duplex.receive(json(envelope('outcome', { session_id: fixture.session.session_id, command_id: 'cmd', state: 'pending', sequence: null, outcome: null }, q2.requestid)));
  const push = { ...fixture.saved[0], requestid: q1.requestid };
  await duplex.receive(json(push));
  await duplex.receive(json(envelope('view', { ...fixture.session, cursor: 0, state: { value: 0 } }, q1.requestid)));
  assert.equal((await one).type, 'dasp.v1.view'); assert.equal((await two).data.state, 'pending');
  assert(notices.some(n => n.kind === 'received' && n.event.type === 'dasp.v1.update'));
  duplex.close();
});
test('duplex drives fixed replay, buffers live output, and saves before resolving', async () => {
  let live = start(3), saved = initial(3);
  const wires = [];
  const duplex = new DuplexTransport({ hostSource: host, send: w => { wires.push(w); }, close() {}, onEvent: async n => {
    if (n.kind === 'closed') { live = live.close(); return; }
    if (n.kind === 'timeout') { live = live.timeout(n.requestid); return; }
    const next = n.kind === 'sent' ? live.sent(n.wire, { replay: n.event.type === 'dasp.v1.updates.read' }) : live.received(n.wire);
    if (next.action === 'save') { await tick(); saved = next.checkpoint; }
    live = next;
  } });
  const c = client(duplex.transport), opening = c.open(fixture.session);
  const q1 = await sent(wires, 1);
  // Queue confirmation and its first push without awaiting a client continuation.
  const confirmation = duplex.receive(json(envelope('session.opened', { ...fixture.session, cursor: 6 }, q1.requestid)));
  const push = duplex.receive(json(fixture.saved[6]));
  await Promise.all([confirmation, push, opening]);
  assert.equal(live.phase, 'replay'); assert.equal(live.target, 6);
  const read = live.nextRead(); assert.equal(read.limit, 3);
  const reading = c.readUpdates(fixture.session, read.after, read.limit), q2 = await sent(wires, 2);
  await duplex.receive(json(envelope('updates', { session_id: fixture.session.session_id, after: 3,
    next: 6, head: 7, events: fixture.saved.slice(3, 6) }, q2.requestid)));
  await reading;
  assert.equal(live.phase, 'live'); assert.equal(live.nextRead(), null);
  assert.equal(saved.cursor, 7); assert.equal(live.checkpoint.cursor, 7);
  duplex.close();
});
test('resync cancels a replay promise and drops its late failure', async () => {
  const wires = []; let live = start(3);
  const duplex = new DuplexTransport({ hostSource: host, send: w => { wires.push(w); }, close() {}, onEvent: n => {
    if (n.kind === 'closed') { live = live.close(); return; }
    if (n.kind === 'timeout') { live = live.timeout(n.requestid); return; }
    live = n.kind === 'sent' ? live.sent(n.wire, { replay: n.event.type === 'dasp.v1.updates.read' }) : live.received(n.wire);
    duplex.cancel(live.cancelledRequests);
  } });
  const c = client(duplex.transport), opening = c.open(fixture.session), q1 = await sent(wires, 1);
  await duplex.receive(json(envelope('session.opened', { ...fixture.session, cursor: 6 }, q1.requestid))); await opening;
  const reading = c.readUpdates(fixture.session, 3, 3), rejection = assert.rejects(reading, code('resync'));
  const q2 = await sent(wires, 2);
  await duplex.receive(json(envelope('resync.required', { session_id: fixture.session.session_id, head: 6, reason: 'overflow' }, q2.requestid)));
  await rejection;
  await duplex.receive(json(envelope('failure', { error: { code: 'unavailable', message: 'Unavailable.', retryable: true } }, q2.requestid)));
  assert.equal(live.checkpoint.cursor, 3); assert.equal(live.phase, 'inactive'); assert.equal(duplex.closed, false);
  duplex.close();
});
test('open timeout closes the connection; another request timeout permits late discard', async () => {
  let closes = 0;
  const duplex = new DuplexTransport({ hostSource: host, send() {}, close() { closes++; } });
  const c = new Client({ source, hostSource: host, transport: duplex.transport, validateProfile: profile, timeoutMs: 10 });
  await assert.rejects(c.open(fixture.session), code('timeout')); await tick();
  assert.equal(duplex.closed, true); assert.equal(closes, 1);
  const wires = [];
  const second = new DuplexTransport({ hostSource: host, send: w => { wires.push(w); }, close() {} });
  const query = new Client({ source, hostSource: host, transport: second.transport, validateProfile: profile, timeoutMs: 10 });
  await assert.rejects(query.readView(fixture.session), code('timeout'));
  const q = JSON.parse(wires[0]);
  await second.receive(json(envelope('view', { ...fixture.session, cursor: 0, state: { value: 0 } }, q.requestid)));
  assert.equal(second.closed, false); second.close();
});
test('malformed input, byte bounds, and callback failure close pending requests', async () => {
  for (const options of [{ maxQueuedBytes: 1 }, { onEvent: () => { throw new Error('store failed'); } }]) {
    const duplex = new DuplexTransport({ hostSource: host, send() {}, close() {}, ...options });
    await assert.rejects(client(duplex.transport).readView(fixture.session));
    assert.equal(duplex.closed, true);
  }
  const duplex = new DuplexTransport({ hostSource: host, send() {}, close() {} });
  const pending = client(duplex.transport).readView(fixture.session);
  const rejected = assert.rejects(pending); await tick();
  await assert.rejects(duplex.receive('{"type":1,"type":2}'));
  await rejected; assert.equal(duplex.closed, true);
});


test('queue count is bounded while an event callback is blocked', async () => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  const duplex = new DuplexTransport({ hostSource: host, maxQueuedMessages: 1,
    send() {}, close() {}, onEvent: n => n.kind === 'sent' ? gate : undefined });
  const pending = client(duplex.transport).readView(fixture.session);
  const rejected = assert.rejects(pending, code('overflow')); await tick();
  await assert.rejects(duplex.receive(json(fixture.saved[0])), code('overflow'));
  release(); await rejected; await duplex.settled; assert.equal(duplex.closed, true);
});

test('failed checkpoint storage retains the prior checkpoint and closes the connection', async () => {
  const wires = []; let live = start(), stored = initial();
  const duplex = new DuplexTransport({ hostSource: host, send: w => wires.push(w), close() {}, onEvent: async n => {
    if (n.kind === 'closed') { live = live.close(); return; }
    const next = n.kind === 'sent' ? live.sent(n.wire) : live.received(n.wire);
    if (next.action === 'save') throw new Error('storage failed');
    live = next;
  } });
  const c = client(duplex.transport), opening = c.open(fixture.session), q = await sent(wires, 1);
  await duplex.receive(json(envelope('session.opened', { ...fixture.session, cursor: 0 }, q.requestid))); await opening;
  const pending = c.readView(fixture.session), rejected = assert.rejects(pending); await sent(wires, 2);
  await assert.rejects(duplex.receive(json(fixture.saved[0])), /storage failed/); await rejected; await tick();
  assert.equal(live.checkpoint.cursor, 0); assert.equal(stored.cursor, 0); assert.equal(duplex.closed, true);
});

test('aborting a queued unsent request does not report an unknown timeout', async () => {
  let release; const gate = new Promise(resolve => { release = resolve; }); const notices = [], wires = [];
  const duplex = new DuplexTransport({ hostSource: host, send: w => wires.push(w), close() {}, onEvent: async n => {
    notices.push(n); if (n.kind === 'sent' && n.event.requestid === 'first') await gate;
  } });
  const a = new AbortController(), b = new AbortController();
  const first = duplex.transport(json(envelope('view.read', { session_id: fixture.session.session_id }, 'first')), { signal: a.signal });
  const firstRejected = assert.rejects(first); await tick();
  const second = duplex.transport(json(envelope('view.read', { session_id: fixture.session.session_id }, 'second')), { signal: b.signal });
  const secondRejected = assert.rejects(second, code('timeout')); b.abort(); release();
  await secondRejected; await duplex.settled;
  assert.equal(wires.length, 1); assert(!notices.some(n => n.kind === 'timeout'));
  duplex.close(); await firstRejected;
});

test('request deadline during checkpoint storage does not create a second state transition', async () => {
  let release; const gate = new Promise(resolve => { release = resolve; }); const wires = []; let live = start();
  const duplex = new DuplexTransport({ hostSource: host, send: w => wires.push(w), close() {}, onEvent: async n => {
    if (n.kind === 'closed') { live = live.close(); return; }
    if (n.kind === 'timeout') { live = live.timeout(n.requestid); return; }
    const next = n.kind === 'sent' ? live.sent(n.wire, { replay: n.event.type === 'dasp.v1.updates.read' }) : live.received(n.wire);
    if (next.action === 'save') await gate;
    live = next;
  } });
  const c = client(duplex.transport), opening = c.open(fixture.session), q = await sent(wires, 1);
  await duplex.receive(json(envelope('session.opened', { ...fixture.session, cursor: 1 }, q.requestid))); await opening;
  const abort = new AbortController();
  const pending = duplex.transport(json(envelope('updates.read', { session_id: fixture.session.session_id, after: 0, limit: 1 }, 'read')), { signal: abort.signal });
  const rejected = assert.rejects(pending, code('timeout')); await sent(wires, 2);
  const receiving = duplex.receive(json(envelope('updates', { session_id: fixture.session.session_id, after: 0, next: 1, head: 1, events: [fixture.saved[0]] }, 'read')));
  await tick(); abort.abort(); release(); await rejected; await receiving; await duplex.settled;
  assert.equal(live.phase, 'live'); assert.equal(live.checkpoint.cursor, 1); assert.equal(duplex.closed, false); duplex.close();
});


test('cancelling a pending open closes the connection', async () => {
  const wires = []; const duplex = new DuplexTransport({ hostSource: host, send: w => wires.push(w), close() {} });
  const opening = client(duplex.transport).open(fixture.session), rejected = assert.rejects(opening, code('resync'));
  const q = await sent(wires, 1); duplex.cancel([q.requestid]); await rejected;
  assert.equal(duplex.closed, true);
});

test('request tracking cannot exceed its connection limit', async () => {
  const wires = []; const duplex = new DuplexTransport({ hostSource: host, maxTrackedRequests: 1, send: w => wires.push(w), close() {} });
  const c = client(duplex.transport), first = c.readView(fixture.session), rejected = assert.rejects(first, code('overflow'));
  await sent(wires, 1); await assert.rejects(c.readView(fixture.session), code('overflow')); await rejected;
  assert.equal(duplex.closed, true);
});
