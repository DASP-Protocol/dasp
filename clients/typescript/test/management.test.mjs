import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setImmediate as tick } from 'node:timers/promises';
import { Client, DuplexTransport, OutputQueue } from '../dist/index.js';
const host = 'urn:host:one', source = 'urn:client:one';
const session = { session_id: 'a', actor_id: 'actor', profile: { id: 'urn:profile:one', version: '1' } };
const code = expected => error => error.code === expected;
const event = (kind, data, requestid = crypto.randomUUID()) => ({ specversion: '1.0', id: crypto.randomUUID(),
  source: host, type: 'dasp.v1.' + kind, datacontenttype: 'application/json', requestid, data });
const update = (id, sequence = 1) => event('update', { session_id: id, sequence, kind: 'application', command_id: null,
  payload: { name: 'changed', data: { value: sequence } } });
const receipt = (id, requestid) => event('receipt', { session_id: id, command_id: 'stable', disposition: 'accepted', admission_sequence: 1, error: null }, requestid);
const progress = (id, value) => event('progress', { session_id: id, command_id: 'stable', name: 'work', payload: { value } });
const make = (extra = {}) => {
  const wires = [], notices = [];
  const duplex = new DuplexTransport({ hostSource: host, send: wire => wires.push(JSON.parse(wire)), close() {},
    onEvent: notice => notices.push(notice), ...extra });
  const client = new Client({ source, hostSource: host, transport: duplex.transport, validateProfile: () => true });
  return { duplex, client, wires, notices };
};
const take = queue => { const item = queue.take(); assert(item); queue.complete(item.token); return item.event; };
test('drain refuses new requests, keeps the pending receipt, and joins the original deadline', async () => {
  const { duplex, client, wires, notices } = make();
  const pending = client.submit(session, { command_id: 'stable', name: 'work', input: {} });
  await tick(); const drained = duplex.drain(1000); assert.equal(duplex.drain(5000), drained);
  await assert.rejects(client.readView(session), code('draining')); assert.equal(wires.length, 1);
  assert.equal(duplex.closed, false); await duplex.receive(JSON.stringify(receipt('a', wires[0].requestid)));
  assert.equal((await pending).data.disposition, 'accepted'); await drained;
  assert.equal(duplex.closed, true); assert.equal(notices.at(-1).error.code, 'drained');
});
test('lost receipt at the drain deadline retains intent on a fresh connection', async () => {
  const first = make(), intent = { command_id: 'stable', name: 'work', input: { amount: 7 } };
  const pending = first.client.submit(session, intent), rejected = assert.rejects(pending, code('drain_timeout'));
  await tick(); await first.duplex.drain(15); await rejected;
  const second = make(), retry = second.client.submit(session, intent); await tick();
  assert.deepEqual(second.wires[0].data, first.wires[0].data);
  assert.notEqual(second.wires[0].requestid, first.wires[0].requestid);
  const duplicate = receipt('a', second.wires[0].requestid); duplicate.data.disposition = 'duplicate';
  await second.duplex.receive(JSON.stringify(duplicate)); assert.equal((await retry).data.disposition, 'duplicate'); second.duplex.close();
});
test('drain waits for the last ordered callback', async () => {
  let release, entered;
  const gate = new Promise(resolve => { release = resolve; }), waiting = new Promise(resolve => { entered = resolve; });
  const { duplex, client, wires } = make({ onEvent: async notice => { if (notice.kind === 'received') { entered(); await gate; } } });
  const pending = client.readView(session); await tick();
  const receiving = duplex.receive(JSON.stringify(event('view', { ...session, cursor: 0, state: {} }, wires[0].requestid)));
  await waiting; const drained = duplex.drain(1000); assert.equal(duplex.closed, false);
  release(); await receiving; await pending; await drained; assert.equal(duplex.closed, true);
});
test('a blocked or failed scoped connection leaves another session usable', async () => {
  let release, entered;
  const gate = new Promise(resolve => { release = resolve; }), waiting = new Promise(resolve => { entered = resolve; });
  const first = make({ sessionId: 'a', onEvent: async notice => { if (notice.kind === 'sent') { entered(); await gate; } } });
  const second = make({ sessionId: 'b' }), two = { ...session, session_id: 'b' };
  const a = first.client.open(session), rejected = assert.rejects(a); await waiting;
  try {
    const b = second.client.readView(two); await tick();
    await second.duplex.receive(JSON.stringify(event('view', { ...two, cursor: 0, state: { alive: true } }, second.wires[0].requestid)));
    assert.equal((await b).data.state.alive, true);
    first.duplex.close(); release(); await rejected;
    assert.equal(second.duplex.closed, false);
  } finally { first.duplex.close(); release(); second.duplex.close(); }
});
test('session scope and driver readiness guard core traffic', async () => {
  let ready = false;
  const { duplex, client, wires } = make({ sessionId: 'a', isReady: () => ready });
  await assert.rejects(client.readView(session), code('not_ready')); assert.equal(wires.length, 0);
  ready = true; await assert.rejects(client.readView({ ...session, session_id: 'b' }), code('correlation'));
  const pending = client.readView(session); await tick();
  await duplex.receive(JSON.stringify(event('view', { ...session, cursor: 0, state: {} }, wires[0].requestid))); await pending;
  await assert.rejects(duplex.receive(JSON.stringify(progress('b', 1))), code('correlation')); assert.equal(duplex.closed, true);
  const unready = make({ isReady: () => false });
  await assert.rejects(unready.duplex.receive(JSON.stringify(progress('a', 1))), code('not_ready')); assert.equal(unready.duplex.closed, true);
});
test('invalid drain deadlines do not stop request admission', async () => {
  const { duplex } = make();
  for (const deadline of [0, -1, 1.5, Infinity, 2_147_483_648]) await assert.rejects(duplex.drain(deadline), code('configuration'));
  assert.equal(duplex.draining, false); await duplex.drain(10);
});
test('readiness loss during a send callback prevents handoff and closes the channel', async () => {
  let ready = true;
  const { duplex, client, wires } = make({ isReady: () => ready, onEvent: notice => { if (notice.kind === 'sent') ready = false; } });
  await assert.rejects(client.readView(session), code('not_ready'));
  assert.equal(wires.length, 0); assert.equal(duplex.closed, true);
});
test('readiness loss after a completed exchange closes instead of retaining setup', async () => {
  let ready = true;
  const { duplex, client, wires } = make({ isReady: () => ready });
  const pending = client.readView(session); await tick();
  await duplex.receive(JSON.stringify(event('view', { ...session, cursor: 0, state: {} }, wires[0].requestid))); await pending;
  ready = false; await assert.rejects(client.readView(session), code('not_ready'));
  assert.equal(wires.length, 1); assert.equal(duplex.closed, true);
  const failed = make({ isReady: () => { throw new Error('driver failed'); } });
  await assert.rejects(failed.client.readView(session), code('transport'));
  assert.equal(failed.wires.length, 0); assert.equal(failed.duplex.closed, true);
});
test('fair output retains each session order and charges the active lease', () => {
  const q = new OutputQueue(); q.enqueue(update('a', 1)); q.enqueue(update('a', 2)); q.enqueue(update('b', 1));
  const first = q.take(); assert.equal(first.event.data.session_id, 'a'); assert.equal(q.usage.messages, 3);
  assert.equal(q.take(), null); assert.throws(() => q.complete(first.token + 1), code('configuration'));
  q.complete(first.token); assert.equal(take(q).data.session_id, 'b'); assert.equal(take(q).data.sequence, 2); assert.equal(q.usage.messages, 0);
});
test('ordinary data and progress cannot consume control message reserves', () => {
  const q = new OutputQueue({ maxMessages: 3, reservedControlMessages: 1 }); q.enqueue(update('a', 1)); q.enqueue(update('a', 2));
  assert.throws(() => q.enqueue(update('b')), code('overflow')); assert.equal(q.enqueue(progress('b', 1)), false); q.enqueue(receipt('b'));
  assert.equal(take(q).type, 'dasp.v1.receipt'); assert.equal(take(q).data.sequence, 1); assert.equal(take(q).data.sequence, 2);
});
test('control preference preserves session order and has a finite burst', () => {
  const q = new OutputQueue({ maxControlBurst: 2 }); q.enqueue(update('a')); q.enqueue(receipt('a'));
  for (let i = 0; i < 3; i++) q.enqueue(receipt('b'));
  assert.equal(take(q).data.session_id, 'b'); assert.equal(take(q).data.session_id, 'b');
  assert.equal(take(q).type, 'dasp.v1.update'); assert.equal(take(q).type, 'dasp.v1.receipt');
});
test('byte reserves remain available for a control reply', () => {
  const a = update('a'), b = receipt('b'), aBytes = Buffer.byteLength(JSON.stringify(a)), bBytes = Buffer.byteLength(JSON.stringify(b));
  const q = new OutputQueue({ maxBytes: aBytes + bBytes, reservedControlBytes: bBytes });
  q.enqueue(a); assert.throws(() => q.enqueue(update('a', 2)), code('overflow')); q.enqueue(b);
  assert.equal(q.usage.bytes, aBytes + bBytes); assert.equal(take(q).type, 'dasp.v1.receipt');
});
test('a busy session reaches its own count and byte limits before blocking another session', () => {
  const q = new OutputQueue({ maxSessionMessages: 2 });
  q.enqueue(update('a', 1)); q.enqueue(update('a', 2));
  assert.throws(() => q.enqueue(update('a', 3)), code('overflow'));
  q.enqueue(update('b')); const first = q.take();
  assert.throws(() => q.enqueue(update('a', 3)), code('overflow'));
  q.complete(first.token); assert.equal(take(q).data.session_id, 'b');
  const a = { ...update('a'), id: 'byte-a' }, bytes = Buffer.byteLength(JSON.stringify(a));
  const limited = new OutputQueue({ maxSessionBytes: bytes }); limited.enqueue(a);
  assert.throws(() => limited.enqueue(update('a', 2)), code('overflow'));
  limited.enqueue({ ...a, id: 'byte-b', data: { ...a.data, session_id: 'b' } });
});
test('coalescing affects only adjacent matching progress', () => {
  const q = new OutputQueue(), original = progress('a', 1); q.enqueue(original); original.data.payload.value = 99; q.enqueue(progress('a', 2));
  assert.equal(q.usage.messages, 1); q.enqueue(update('a')); q.enqueue(progress('a', 3));
  assert.equal(take(q).data.payload.value, 2); assert.equal(take(q).data.sequence, 1); assert.equal(take(q).data.payload.value, 3);
});
test('resync discards unsent attachment data but keeps replies and source records', () => {
  const q = new OutputQueue(), saved = update('a'), before = JSON.stringify(saved);
  q.enqueue(saved); q.enqueue(progress('a', 1)); q.enqueue(receipt('a')); q.enqueue(update('b'));
  assert.equal(q.discardUpdates('a'), 2); assert.equal(JSON.stringify(saved), before);
  assert.equal(take(q).type, 'dasp.v1.receipt'); assert.equal(take(q).data.session_id, 'b');
});
test('invalid queue settings and closed lease reuse fail', () => {
  for (const options of [{ maxMessages: 0 }, { maxBytes: 5, reservedControlBytes: 5 }, { maxControlBurst: 1.5 }]) assert.throws(() => new OutputQueue(options), code('configuration'));
  const q = new OutputQueue(); q.enqueue(update('a')); q.take(); q.close(); assert.equal(q.usage.messages, 0); assert.throws(() => q.take(), code('closed'));
});
