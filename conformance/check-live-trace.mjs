import assert from 'node:assert/strict';

// Check recorded examples, not a host, socket, client adapter, or persistence store.
// Reads in these transcripts are recovery reads; the binding also permits ordinary reads.
export function checkLiveTrace(trace, validate) {
  const saved = new Map(trace.saved.map(event => [event.data.sequence, event]));
  assert.equal(saved.size, trace.saved.length);
  assert.equal(new Set(trace.saved.map(event => `${event.source}\0${event.id}`)).size, saved.size);
  for (const [index, event] of trace.saved.entries()) {
    assert(validate(event), JSON.stringify(validate.errors));
    assert.equal(event.type, 'dasp.v1.update');
    assert.equal(event.data.sequence, index + 1);
    assert.equal(event.data.session_id, 'session-counter');
  }
  assert.equal(new Set(trace.scenarios.map(scenario => scenario.id)).size, trace.scenarios.length);
  for (const scenario of trace.scenarios) {
    let { cursor, state, head } = structuredClone(scenario.initial);
    let phase = 'inactive', target = null, nextPush = null;
    let replayReads = 0, discardedReplies = 0;
    let buffer = [];
    const applied = [], pending = new Map(), cancelled = new Set(), sent = new Set();
    assert.equal(new Set(scenario.steps.map(step => step.id)).size, scenario.steps.length);
    const active = () => phase === 'replay' || phase === 'live';
    const apply = event => {
      const sequence = event.data.sequence;
      assert.deepEqual(event, saved.get(sequence), 'Changed saved identity or data');
      if (sequence <= cursor) return; // Compare with this example's saved duplicate evidence.
      assert.equal(sequence, cursor + 1, 'Application gap');
      if (event.data.kind === 'application') state = structuredClone(event.data.payload.data);
      cursor = sequence;
      applied.push(sequence);
    };
    const finishReplay = () => {
      if (phase !== 'replay' || cursor < target) return;
      phase = 'live';
      for (const event of buffer) apply(event);
      buffer = [];
    };
    for (const step of scenario.steps) {
      if (step.action === 'commit') {
        assert.equal(step.sequence, head + 1, 'Commit gap');
        assert(saved.has(step.sequence));
        head = step.sequence;
        continue;
      }
      if (step.action === 'close') {
        assert(active());
        phase = 'closed';
        buffer = [];
        pending.clear();
        continue;
      }
      assert(['send', 'receive'].includes(step.action), 'Unknown transcript action');
      const event = step.event;
      assert(validate(event), `Invalid event in ${step.id}: ${JSON.stringify(validate.errors)}`);
      assert.equal(event.data.session_id, 'session-counter');
      const kind = event.type.slice('dasp.v1.'.length);
      if (step.action === 'send') {
        assert(!sent.has(event.requestid), 'Repeated request ID on the connection');
        sent.add(event.requestid);
        pending.set(event.requestid, event);
        if (kind === 'session.open') {
          assert(phase !== 'closed' && phase !== 'opening');
          assert.equal([...pending.values()].filter(request => request.type === event.type).length, 1);
          if (!active()) phase = 'opening';
        } else if (kind === 'updates.read') {
          assert.equal(phase, 'replay', 'Recovery must not chase a newer page head');
          assert.equal(event.data.after, cursor);
          replayReads++;
        } else {
          assert.equal(kind, 'command');
          assert(active());
        }
        continue;
      }
      if (kind === 'update') {
        assert(active(), 'Push before confirmation or after attachment stop');
        assert.equal(event.data.sequence, nextPush, 'Live delivery gap or repeat');
        assert(event.data.sequence <= head, 'Push before commit');
        assert.deepEqual(event, saved.get(event.data.sequence), 'Changed pushed saved fact');
        nextPush++;
        if (phase === 'replay') buffer.push(event);
        else apply(event);
        continue;
      }
      if (kind === 'resync.required') {
        assert(active());
        assert(event.data.head <= head);
        phase = 'inactive';
        buffer = [];
        for (const [id, request] of pending) {
          if (request.type === 'dasp.v1.updates.read') { cancelled.add(id); pending.delete(id); }
        }
        continue;
      }
      if (cancelled.has(event.requestid)) {
        assert.equal(kind, 'updates');
        discardedReplies++;
        continue;
      }
      const request = pending.get(event.requestid);
      assert(request, 'Reply has no current request');
      pending.delete(event.requestid);
      if (kind === 'session.opened') {
        assert.equal(request.type, 'dasp.v1.session.open');
        const { cursor: replyHead, ...tuple } = event.data;
        assert.deepEqual(tuple, request.data);
        assert.equal(replyHead, head);
        assert(cursor <= replyHead, 'Lost continuity');
        if (!active()) nextPush = replyHead + 1;
        target = replyHead;
        phase = cursor < target ? 'replay' : 'live';
      } else if (kind === 'updates') {
        assert.equal(request.type, 'dasp.v1.updates.read');
        assert.equal(phase, 'replay');
        assert.equal(event.data.after, request.data.after);
        assert(event.data.head >= event.data.after && event.data.head <= head);
        assert(event.data.events.length > 0 && event.data.events.length <= request.data.limit);
        let sequence = event.data.after;
        for (const update of event.data.events) {
          assert.equal(update.data.sequence, ++sequence, 'Replay gap');
          assert(sequence <= event.data.head);
          apply(update);
        }
        assert.equal(event.data.next, sequence);
        finishReplay();
      } else {
        assert.equal(kind, 'receipt');
        assert.equal(request.type, 'dasp.v1.command');
        assert.equal(event.data.command_id, request.data.command_id);
        assert.equal(event.data.disposition, 'accepted');
        const admission = saved.get(event.data.admission_sequence);
        assert(admission && admission.data.sequence <= head);
        assert.equal(admission.data.kind, 'command.accepted');
        assert.equal(admission.data.command_id, request.data.command_id);
      }
    }
    assert.deepEqual({ cursor, state, applied, replayReads, discardedReplies, phase }, scenario.expected);
    assert.equal(pending.size, 0, 'Unanswered transcript request');
  }
  return { liveScenarios: trace.scenarios.length, liveTraceSteps: trace.scenarios.reduce((count, scenario) => count + scenario.steps.length, 0) };
}
