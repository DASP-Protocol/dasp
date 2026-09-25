import assert from 'node:assert/strict';

// Check a recorded contract example. This function does not execute a host.
export function checkTrace(trace, validate) {
  const steps = new Map(trace.steps.map(step => [step.id, step]));
  assert.equal(steps.size, trace.steps.length, 'Trace step IDs must be unique');
  const get = id => { assert(steps.has(id), `Missing trace step ${id}`); return steps.get(id).event; };
  for (const step of trace.steps) assert(validate(step.event), `Invalid trace event ${step.id}`);
  assert.equal(new Set(trace.steps.map(s => `${s.event.source}\0${s.event.id}`)).size, trace.steps.length);
  const command = get('command');
  const retry = get('retry');
  assert.deepEqual(retry.data, command.data, 'Retry must preserve complete intent');
  assert.notEqual(retry.requestid, command.requestid);
  assert.equal(steps.get('lost-receipt').delivery, 'dropped');
  assert.equal(get('lost-receipt').requestid, command.requestid);
  assert.equal(get('duplicate').requestid, retry.requestid);
  assert.equal(get('duplicate').data.disposition, 'duplicate');
  const saved = ['admission', 'state', 'settlement'].map(get);
  assert.deepEqual(saved.map(e => e.data.sequence), [1, 2, 3]);
  assert.equal(saved[0].data.kind, 'command.accepted');
  assert.equal(saved[1].data.payload.name, 'counter.changed');
  assert.equal(saved[2].data.kind, 'command.outcome');
  assert.equal(get('lost-receipt').data.admission_sequence, saved[0].data.sequence);
  assert.equal(get('duplicate').data.admission_sequence, saved[0].data.sequence);
  assert.deepEqual(get('outcome').data.outcome, saved[2].data.payload);
  assert.equal(get('outcome').data.sequence, saved[2].data.sequence);
  assert.equal(get('outcome').requestid, get('outcome-read').requestid);
  assert.equal(saved[1].data.payload.data.value, command.data.input.amount);
  assert.equal(saved[2].data.payload.output.value, command.data.input.amount);
  assert.equal(get('changed-command').data.command_id, command.data.command_id);
  assert.notDeepEqual(get('changed-command').data.input, command.data.input);
  assert.equal(get('conflict').data.disposition, 'rejected');
  assert.equal(get('conflict').data.error.code, 'conflict');
  assert.equal(get('conflict').requestid, get('changed-command').requestid);
  for (const e of trace.steps.map(s => s.event)) {
    assert.equal(e.data.session_id, command.data.session_id);
    if ('command_id' in e.data) assert.equal(e.data.command_id, command.data.command_id);
  }
  assert.equal(trace.clients.length, 2);
  assert.equal(new Set(trace.clients.map(c => c.id)).size, 2);
  for (const client of trace.clients) {
    const page = get(client.page);
    const read = get(`read-${client.id}`);
    assert.equal(page.requestid, read.requestid);
    assert.equal(page.data.after, client.initial.cursor);
    assert.equal(read.data.after, client.initial.cursor);
    assert.deepEqual(page.data.events, saved.filter(e => e.data.sequence > client.initial.cursor), 'Replay must preserve saved event bytes');
    let state = structuredClone(client.initial.state);
    let cursor = client.initial.cursor;
    for (const event of page.data.events) {
      assert.equal(event.data.sequence, cursor + 1, 'Replay gap');
      if (event.data.kind === 'application') state = structuredClone(event.data.payload.data);
      cursor = event.data.sequence;
    }
    assert.equal(page.data.next, cursor);
    assert.equal(page.data.head, saved.at(-1).data.sequence);
    assert.deepEqual({ cursor, state }, client.expected);
  }
  assert.notEqual(get('read-one').source, get('read-two').source);
  return true;
}
