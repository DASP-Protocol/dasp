import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Client, decode, encode, applyUpdates, checkpointFromView } from "../dist/index.js";

const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));
const valid = read("../../../specification/draft-01/examples/counter.json");
const invalid = read("../../../conformance/fixtures/invalid-events.json");
const trace = read("../../../conformance/fixtures/recovery-trace.json");
const step = id => structuredClone(trace.steps.find(s => s.id === id).event);
const session = step("open").data;
const command = step("command").data;
const profile = () => true; // These tests focus on core behavior; profile rejection is tested below.
const options = { source: "urn:example:client:one", hostSource: "urn:example:host:one", validateProfile: profile };
const reply = (request, id) => JSON.stringify({ ...step(id), requestid: JSON.parse(request).requestid });
const client = (transport, extra = {}) => new Client({ ...options, transport, ...extra });
const submit = c => c.submit(session, { command_id: command.command_id, name: command.name, input: command.input });
const reducer = (state, event) => event.data.kind === "application" ? event.data.payload.data : state;
const checkpoint = (cursor = 0, state = { value: 0 }) => checkpointFromView({
  ...step("opened"), type: "dasp.view.v1", data: { ...session, cursor, state }
}, profile);
const code = expected => error => error.code === expected;

for (const [i, event] of valid.entries()) test("valid draft event " + i, () => {
  assert.equal(JSON.stringify(decode(encode(event))), JSON.stringify(event));
});
for (const vector of invalid) test("reject draft vector " + vector.id, () => {
  assert.throws(() => decode(JSON.stringify(vector.event)));
});
for (const token of ["0.5", "1.00000000000000001", "9007199254740992", "9.0071992547409911e15", "1e99999", "1e-99999"]) {
  test("reject exact nonportable number " + token, () => {
    assert.throws(() => decode(JSON.stringify(step("command")).replace('"amount":3', '"amount":' + token)));
  });
}
test("integer exponent and decimal notation retain exact values", () => {
  for (const token of ["3.0", "30e-1", "0.003e3"]) {
    const event = decode(JSON.stringify(step("command")).replace('"amount":3', '"amount":' + token));
    assert.equal(event.data.input.amount, 3);
  }
});
test("reject duplicate keys, invalid Unicode, and lossy local values", () => {
  const text = JSON.stringify(step("command"));
  for (const bad of [
    text.replace('"amount":3', '"amount":3,"\\u0061mount":4'),
    text.replace('"amount":3', '"amount":"\\ud800"'),
    Buffer.from([0xff]), text + " null", " ".repeat(1_048_577)
  ]) assert.throws(() => decode(bad));
  for (const value of [undefined, NaN, 1.5, new Date(), BigInt(1), [, 1]]) {
    const event = step("command"); event.data.input.amount = value;
    assert.throws(() => encode(event));
  }
  const event = step("command");
  Object.defineProperty(event.data.input, "amount", { get() { throw Error("must not run"); }, enumerable: true });
  assert.throws(() => encode(event), code("invalid_json"));
  const hidden = step("command");
  Object.defineProperty(hidden.data.input, "toJSON", { value: () => ({ amount: 4 }) });
  assert.throws(() => encode(hidden), code("invalid_json"));
  const sparse = step("command");
  const items = [1, 2]; delete items[1]; items.extra = 3;
  sparse.data.input.items = items;
  assert.throws(() => encode(sparse), code("invalid_json"));
});
test("enforce subject and profile payload limits", () => {
  const subject = step("command"); subject.subject = "other";
  assert.throws(() => encode(subject));
  for (const input of [{ text: "x".repeat(65_537) }, { items: Array(1025).fill(0) },
    Array.from({ length: 16 }).reduce(a => ({ nested: a }), {})]) {
    const event = step("command"); event.data.input = input;
    assert.throws(() => encode(event));
  }
});
test("update byte limits include whitespace inside replay pages", () => {
  const update = JSON.stringify(step("admission"));
  const padded = update.replace("{", "{" + " ".repeat(65_536));
  assert.throws(() => decode(padded));
  const page = step("page-two");
  page.data.events = [step("admission")]; page.data.next = 1;
  assert.throws(() => decode(JSON.stringify(page).replace(update, padded)));
});
test("lost receipt retry preserves command identity and changes attempt identity", async () => {
  const requests = [];
  const c = client(async wire => {
    requests.push(JSON.parse(wire));
    if (requests.length === 1) throw Error("connection lost");
    return reply(wire, "duplicate");
  });
  await assert.rejects(submit(c), code("transport"));
  const receipt = await submit(c);
  assert.equal(receipt.data.disposition, "duplicate");
  assert.equal(receipt.data.outcome, undefined);
  assert.deepEqual(requests[0].data, requests[1].data);
  assert.notEqual(requests[0].requestid, requests[1].requestid);
  assert.notEqual(requests[0].id, requests[1].id);
});
test("request APIs keep admission, view, replay, and outcome separate", async () => {
  assert.equal((await client(async w => reply(w, "opened")).open(session)).data.cursor, 0);
  assert.equal((await client(async w => reply(w, "outcome")).readOutcome(session, command.command_id)).data.state, "settled");
  const view = { ...step("opened"), type: "dasp.view.v1", data: { ...session, cursor: 3, state: { value: 3 } } };
  assert.equal((await client(async w => JSON.stringify({ ...view, requestid: JSON.parse(w).requestid })).readView(session)).data.cursor, 3);
  const pending = { ...step("outcome"), data: { ...step("outcome").data, state: "pending", sequence: null, outcome: null } };
  assert.equal((await client(async w => JSON.stringify({ ...pending, requestid: JSON.parse(w).requestid })).readOutcome(session, command.command_id)).data.state, "pending");
});
test("timeout aborts the adapter without retrying or reporting rejection", async () => {
  let calls = 0, aborted = false;
  const c = client(async (_, { signal }) => {
    calls++;
    signal.addEventListener("abort", () => { aborted = true; });
    return new Promise(() => {});
  }, { timeoutMs: 10 });
  await assert.rejects(submit(c), code("timeout"));
  assert.equal(calls, 1); assert.equal(aborted, true);
});
for (const mutate of [
  e => { e.requestid = "wrong"; }, e => { e.source = "urn:other:host"; },
  e => { e.data.session_id = "wrong"; }, e => { e.data.command_id = "wrong"; }
]) test("reject mismatched reply context", async () => {
  await assert.rejects(submit(client(async w => {
    const e = JSON.parse(reply(w, "duplicate")); mutate(e); return JSON.stringify(e);
  })), code("correlation"));
});
test("remote failure remains a distinct error", async () => {
  const c = client(async w => JSON.stringify({
    ...step("duplicate"), requestid: JSON.parse(w).requestid, type: "dasp.failure.v1",
    data: { error: { code: "unauthorized", message: "Access denied.", retryable: false } }
  }));
  await assert.rejects(submit(c), e => e.code === "remote_failure" && e.detail.code === "unauthorized");
});
test("profile rejection stops send and nested replay application", async () => {
  let sent = false;
  await assert.rejects(submit(client(async () => { sent = true; }, { validateProfile: () => false })), code("profile"));
  assert.equal(sent, false);
  const c = client(async w => reply(w, "page-two"), { validateProfile: e => e.type !== "dasp.update.v1" });
  await assert.rejects(c.readUpdates(session, 0), code("profile"));
});
test("reply actor and profile must match the requested session", async () => {
  for (const field of ["actor_id", "profile"]) {
    const c = client(async w => {
      const e = JSON.parse(reply(w, "opened"));
      e.data[field] = field === "actor_id" ? "other" : { id: "urn:other:profile", version: "1" };
      return JSON.stringify(e);
    });
    await assert.rejects(c.open(session), code("correlation"));
  }
});
test("replay validates page bounds, contiguity, session, source, and limit", async () => {
  for (const mutate of [
    e => { e.data.after = 1; }, e => { e.data.next = 2; }, e => { e.data.head = 2; },
    e => { e.data.events = []; }, e => { e.data.events[1].data.sequence = 3; },
    e => { e.data.events[0].data.session_id = "other"; },
    e => { e.data.events[0].source = "urn:other:host"; }
  ]) {
    const c = client(async w => { const e = JSON.parse(reply(w, "page-two")); mutate(e); return JSON.stringify(e); });
    await assert.rejects(c.readUpdates(session, 0));
  }
  await assert.rejects(client(async w => reply(w, "page-two")).readUpdates(session, 0, 1), code("replay"));
});
for (const consumer of trace.clients) test("recover recorded client " + consumer.id, async () => {
  const start = checkpoint(consumer.initial.cursor, consumer.initial.state);
  const page = await client(async w => reply(w, consumer.page)).readUpdates(session, start.cursor);
  const saved = applyUpdates(start, page.data.events, reducer, profile);
  assert.deepEqual({ cursor: saved.cursor, state: saved.state }, consumer.expected);
  assert.equal(start.cursor, consumer.initial.cursor);
  const restored = JSON.parse(JSON.stringify(saved));
  assert.deepEqual(applyUpdates(restored, page.data.events, reducer, profile), restored);
});
test("gaps, changed duplicates, and missing evidence stop cursor advancement", () => {
  const start = checkpoint();
  assert.throws(() => applyUpdates(start, [step("state")], reducer, profile), code("gap"));
  const saved = applyUpdates(start, [step("admission")], reducer, profile);
  const changed = step("admission"); changed.id = "changed";
  assert.throws(() => applyUpdates(saved, [changed], reducer, profile), code("changed_update"));
  assert.throws(() => applyUpdates(checkpoint(1), [step("admission")], reducer, profile), code("missing_evidence"));
  assert.throws(() => applyUpdates(start, [step("lost-receipt")], reducer, profile), code("checkpoint"));
  assert.equal(start.cursor, 0);
});
test("reducer failure cannot mutate the input checkpoint", () => {
  const start = checkpoint();
  assert.throws(() => applyUpdates(start, [step("admission")], s => { s.value = 9; throw Error("store failed"); }, profile));
  assert.equal(start.state.value, 0); assert.equal(start.cursor, 0);
});
