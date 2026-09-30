import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';

// Recorded counter examples only; no socket, host, adapter, or persistence execution.
// handle-open records the host decision separately from client reply receipt.
// Reads here are recovery reads; ordinary explicit reads remain permitted by the binding.
export function checkLiveTrace(trace, validate, profile) {
  assert.equal(typeof profile?.input, 'function', 'Counter input validator required');
  assert.equal(typeof profile?.state, 'function', 'Counter state validator required');
  assert.deepEqual(trace.session, {
    session_id: 'session-counter', actor_id: 'counter-main',
    profile: { id: 'urn:example:dasp:counter', version: '1' }
  });
  const saved = new Map(trace.saved.map(event => [event.data.sequence, event]));
  assert.equal(saved.size, trace.saved.length);
  assert.equal(new Set(trace.saved.map(event => `${event.source}\0${event.id}`)).size, saved.size);
  const checkResource = event => {
    if (event.type !== 'dasp.v1.failure') assert.equal(event.data.session_id, trace.session.session_id);
    if (event.subject !== undefined) assert.equal(event.subject, trace.session.session_id, 'Wrong session subject');
  };
  for (const [index, event] of trace.saved.entries()) {
    assert(validate(event), JSON.stringify(validate.errors));
    assert.equal(event.type, 'dasp.v1.update');
    assert.equal(event.data.sequence, index + 1);
    checkResource(event);
    if (event.data.kind === 'application') {
      assert.equal(event.data.payload.name, 'counter.changed');
      assert(profile.state(event.data.payload.data), 'Invalid counter update');
    } else if (event.data.kind === 'command.accepted') {
      assert.equal(event.data.payload.name, 'counter.add');
    } else if (event.data.payload.status === 'completed') {
      assert(profile.state(event.data.payload.output), 'Invalid counter outcome');
    }
  }
  assert.equal(new Set(trace.scenarios.map(scenario => scenario.id)).size, trace.scenarios.length);
  for (const scenario of trace.scenarios) {
    let { cursor, state, head } = structuredClone(scenario.initial);
    assert(profile.state(state), 'Invalid initial counter state');
    let phase = 'inactive', target = null, nextPush = null, hostAttached = false;
    let replayReads = 0, discardedReplies = 0, failedReplies = 0;
    let buffer = [];
    const applied = [], pending = new Map(), cancelled = new Set(), sent = new Set();
    const decisions = new Map(), identities = new Map();
    assert.equal(new Set(scenario.steps.map(step => step.id)).size, scenario.steps.length);
    const active = () => phase === 'replay' || phase === 'live';
    const apply = event => {
      const sequence = event.data.sequence;
      assert.deepEqual(event, saved.get(sequence), 'Changed saved identity or data');
      if (sequence <= cursor) return; // Saved history supplies duplicate evidence in these examples.
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
      if (step.action === 'handle-open') {
        const request = pending.get(step.requestid);
        assert.equal(request?.type, 'dasp.v1.session.open', 'Open capture has no request');
        assert(!decisions.has(step.requestid), 'Open handled twice');
        assert.equal(step.head, head, 'Captured head differs from committed head');
        const conflict = !isDeepStrictEqual(request.data, trace.session);
        decisions.set(step.requestid, { head, kind: conflict ? 'conflict' : hostAttached ? 'retained' : 'new' });
        if (!conflict) hostAttached = true;
        continue;
      }
      if (step.action === 'close' || step.action === 'open-timeout') {
        if (step.action === 'open-timeout') {
          assert([...pending.values()].some(request => request.type === 'dasp.v1.session.open'));
        } else assert(active());
        phase = 'closed';
        hostAttached = false;
        buffer = [];
        pending.clear();
        decisions.clear();
        continue;
      }
      assert(['send', 'receive'].includes(step.action), 'Unknown transcript action');
      const event = step.event;
      assert(validate(event), `Invalid event in ${step.id}: ${JSON.stringify(validate.errors)}`);
      const identity = `${event.source}\0${event.id}`;
      if (identities.has(identity)) assert.deepEqual(event, identities.get(identity), 'Reused outer event identity');
      else identities.set(identity, event);
      const kind = event.type.slice('dasp.v1.'.length);
      if (step.action === 'send') {
        checkResource(event);
        assert(phase !== 'closed', 'Request after connection close');
        assert(!sent.has(event.requestid), 'Repeated request ID on the connection');
        if (kind === 'session.open') {
          assert(![...pending.values()].some(request => request.type === event.type), 'Second pending open');
          if (!active()) phase = 'opening';
        } else if (kind === 'updates.read') {
          assert.equal(phase, 'replay', 'Recovery must not chase a newer page head');
          assert.equal(event.data.after, cursor, 'Read skips applied position');
          replayReads++;
        } else {
          assert.equal(kind, 'command');
          assert(active());
          assert.equal(event.data.name, 'counter.add');
          assert(profile.input(event.data.input), 'Invalid counter command input');
        }
        sent.add(event.requestid);
        pending.set(event.requestid, event);
        continue;
      }
      if (kind === 'update') {
        checkResource(event);
        assert(active() && hostAttached, 'Push before confirmation or after attachment stop');
        assert.equal(event.data.sequence, nextPush, 'Live delivery gap or repeat');
        assert(event.data.sequence <= head, 'Push before commit');
        assert.deepEqual(event, saved.get(event.data.sequence), 'Changed pushed saved fact');
        nextPush++;
        if (phase === 'replay') buffer.push(event);
        else apply(event);
        continue;
      }
      if (kind === 'resync.required') {
        checkResource(event);
        assert(active());
        assert(![...decisions.values()].some(decision => decision.kind !== 'conflict'), 'Resync precedes an earlier successful open reply');
        assert(event.data.head <= head);
        hostAttached = false;
        phase = 'inactive';
        buffer = [];
        for (const [id, request] of pending) {
          if (request.type === 'dasp.v1.updates.read') { cancelled.add(id); pending.delete(id); }
        }
        continue;
      }
      // Only direct replies use correlation. Pushes were processed above.
      if (cancelled.has(event.requestid)) {
        assert(['updates', 'failure'].includes(kind), 'Wrong cancelled reply type');
        discardedReplies++;
        continue;
      }
      const request = pending.get(event.requestid);
      assert(request, 'Reply has no current request');
      checkResource(event);
      pending.delete(event.requestid);
      if (kind === 'session.opened') {
        assert.equal(request.type, 'dasp.v1.session.open');
        const decision = decisions.get(event.requestid);
        assert(decision, 'Open reply has no captured head');
        assert.notEqual(decision.kind, 'conflict', 'Conflicting open confirmed');
        const { cursor: replyHead, ...tuple } = event.data;
        assert.deepEqual(tuple, request.data);
        assert.deepEqual(tuple, trace.session, 'Changed session tuple');
        assert.equal(replyHead, decision.head, 'Reply differs from captured head');
        decisions.delete(event.requestid);
        if (decision.kind === 'retained') {
          assert(active(), 'Retained open after attachment stop');
          // Keep target, phase, nextPush, and buffer, including when cursor > replyHead.
        } else {
          assert(!active(), 'Second active attachment');
          assert(cursor <= replyHead, 'Lost continuity');
          nextPush = replyHead + 1;
          target = replyHead;
          phase = cursor < target ? 'replay' : 'live';
        }
      } else if (kind === 'failure') {
        if (request.type === 'dasp.v1.session.open') {
          const decision = decisions.get(event.requestid);
          assert.equal(decision?.kind, 'conflict', 'This example requires a conflicting open');
          assert.equal(event.data.error.code, 'conflict');
          decisions.delete(event.requestid);
          if (!active()) phase = 'inactive';
        } else assert.equal(request.type, 'dasp.v1.updates.read');
        failedReplies++;
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
          checkResource(update);
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
    assert.deepEqual({ cursor, state, applied, replayReads, discardedReplies, failedReplies, phase, target, nextPush }, scenario.expected);
    assert.equal(pending.size, 0, 'Unanswered transcript request');
    assert.equal(decisions.size, 0, 'Unanswered host open decision');
  }
  return { liveScenarios: trace.scenarios.length, liveTraceSteps: trace.scenarios.reduce((count, scenario) => count + scenario.steps.length, 0) };
}
