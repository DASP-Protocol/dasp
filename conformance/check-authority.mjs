import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createPublicKey, verify } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { parseAuthorityGrant } from './parse-authority-grant.mjs';
import { checkProtocolString } from './parse-protected-header.mjs';

// Artifact checks and a serial evaluator for recorded admission decisions only.
// This is not a host, a durable transaction, a binding, or an independent crypto implementation.
export function checkAuthorityArtifacts(ajv, validateCore, counterProfile) {
  const read = path => JSON.parse(readFileSync(path));
  const schema = read('specification/draft-01/bindings/authority-grant.schema.json');
  const scopeSchema = read('specification/draft-01/examples/counter-authority.schema.json');
  const fixture = read('conformance/fixtures/authority-grants.json');
  const traces = read('conformance/fixtures/authority-traces.json');
  ajv.addSchema(schema); ajv.addSchema(scopeSchema);
  const validateGrant = ajv.getSchema(scopeSchema.$id);
  const validateSelection = ajv.compile({ $ref: schema.$id + '#/$defs/selection' });
  const validateExtension = ajv.compile({ $ref: schema.$id + '#/$defs/extension' });
  const publicKey = createPublicKey({ key: Buffer.from('302a300506032b6570032100' + fixture.public_key_hex, 'hex'), type: 'spki', format: 'der' });
  const records = new Map(fixture.grants.map(g => [g.id, g]));
  assert.equal(records.size, fixture.grants.length, 'Unique fixture grant names');
  const canonicalBytes = (text, max) => {
    assert(/^[A-Za-z0-9_-]+$/.test(text), 'Base64url alphabet');
    assert(text.length <= Math.ceil(4 * max / 3), 'Encoded byte bound');
    const bytes = Buffer.from(text, 'base64url');
    assert.equal(bytes.toString('base64url'), text, 'Canonical base64url');
    assert(bytes.length > 0 && bytes.length <= max, 'Decoded byte bound');
    return bytes;
  };
  const carriage = (extension, limit = fixture.selection.grant_bytes) => {
    assert(validateExtension(extension), 'Extension scalar shape');
    assert(extension.length <= Math.ceil(4 * limit / 3) + 87, 'Extension byte bound');
    if (extension === 'recover') return null;
    const [statement, signature] = extension.split('.');
    const B = canonicalBytes(statement, limit), S = canonicalBytes(signature, 64);
    assert.equal(S.length, 64, 'Signature length');
    return { B, S };
  };
  const proofMessage = B => {
    const size = Buffer.alloc(4); size.writeUInt32BE(B.length);
    return Buffer.concat([Buffer.from('dasp proof of authority\0'), size, B]);
  };
  const checkShape = B => {
    const grant = parseAuthorityGrant(B);
    assert(validateGrant(grant), JSON.stringify(validateGrant.errors));
    for (const name of ['issuer', 'agent', 'authority']) {
      checkProtocolString(grant[name]);
      assert(Buffer.byteLength(grant[name]) <= 512, 'Identifier byte bound');
    }
    assert(grant.not_before < grant.expires_at, 'Grant validity interval');
    const scope = grant.kind === 'standing' ? grant.scope : grant.target;
    checkProtocolString(scope.profile.id); checkProtocolString(scope.profile.version);
    assert(Buffer.byteLength(scope.profile.id) <= 512 && Buffer.byteLength(scope.profile.version) <= 128, 'Profile identifier byte bound');
    if (grant.kind === 'standing') {
      assert.equal(new Set(grant.scope.commands.map(c => c.name)).size, grant.scope.commands.length, 'Duplicate command rule');
      for (const c of grant.scope.commands) assert(c.input_scope.amount_min <= c.input_scope.amount_max, 'Inverted input scope');
    }
    return grant;
  };
  const evidence = extension => {
    const { B, S } = carriage(extension);
    const grant = checkShape(B);
    assert(verify(null, proofMessage(B), publicKey, S), 'Grant signature');
    return { grant, B };
  };

  const selection = (value, requiredKind = 'standing') => {
    assert(validateSelection(value), JSON.stringify(validateSelection.errors));
    assert.equal(value.scope_schema, scopeSchema.$id);
    assert.deepEqual(value.profile, { id: 'urn:example:dasp:counter', version: '1' });
    for (const [text, maximum] of [[value.contract, 512], [value.scope_schema, 512], [value.profile.id, 512], [value.profile.version, 128]]) {
      checkProtocolString(text); assert(Buffer.byteLength(text) <= maximum, 'Selection identifier byte bound');
    }
    assert.equal(new Set(value.commands.map(c => c.name)).size, value.commands.length, 'Duplicate selected command');
    assert(value.commands.every(c => c.name === 'counter.add'), 'Unsupported scope command');
    assert(value.commands.every(c => c.kind === requiredKind), 'Selection weakens required host proof kind');
  };
  selection(fixture.selection);
  for (const field of ['contract', 'profile', 'scope_schema', 'commands', 'grant_bytes']) {
    const broken = structuredClone(fixture.selection); delete broken[field];
    assert.equal(validateSelection(broken), false, `Missing selection ${field}`);
  }
  const unknownSelection = { ...fixture.selection, optional: true };
  assert.equal(validateSelection(unknownSelection), false);

  let negativeCount = 0;
  const reject = (name, fn) => { assert.throws(fn, undefined, name); negativeCount++; };
  reject('duplicate selected command', () => selection({ ...fixture.selection, commands: [...fixture.selection.commands, ...fixture.selection.commands] }));
  reject('unknown selected scope', () => selection({ ...fixture.selection, scope_schema: 'urn:example:unknown' }));
  reject('unsupported selected command', () => selection({ ...fixture.selection, commands: [{ name: 'counter.other', kind: 'standing' }] }));
  reject('standing selection bypasses direct requirement', () => selection(fixture.selection, 'command'));
  selection({ ...fixture.selection, commands: [{ name: 'counter.add', kind: 'command' }] }, 'command');
  for (const item of fixture.grants) {
    const { grant, B } = evidence(item.extension);
    assert.deepEqual(grant, item.statement, item.id);
    assert.equal(B.toString('utf8'), item.bytes, 'Original statement bytes');
    assert.equal(proofMessage(B).toString('hex'), item.message_hex, 'Pinned signature input');
    assert.equal(item.extension.split('.')[1], item.signature);
    // A changed signature or signed byte must not verify.
    const { S } = carriage(item.extension), changed = Buffer.from(S); changed[0] ^= 1;
    reject(`${item.id}: signature`, () => assert(verify(null, proofMessage(B), publicKey, changed)));
    reject(`${item.id}: message`, () => assert(verify(null, proofMessage(Buffer.concat([B, Buffer.from(' ')])), publicKey, S)));
  }
  for (const item of fixture.invalid_grants) reject(item.id, () => evidence(item.extension));
  const original = records.get('standing');
  for (const [id, raw] of [
    ['duplicate decoded key', original.bytes.replace('"issuer":', '"iss\\u0075er":"urn:other","issuer":')],
    ['fraction rounding', original.bytes.replace('1790787600', '1790787600.00000001')],
    ['exponent', original.bytes.replace('1790787600', '1790787600e0')],
    ['negative zero', original.bytes.replace('1790787600', '-0')],
    ['unsafe integer', original.bytes.replace('1790787600', '9007199254740992')],
    ['surrogate', original.bytes.replace('counter-main', '\\ud800')],
    ['trailing input', original.bytes + '{}'],
    ['trailing comma', original.bytes.slice(0, -1) + ',}']
  ]) reject(id, () => checkShape(Buffer.from(raw)));
  reject('invalid UTF-8', () => parseAuthorityGrant(Buffer.from([0xff])));
  reject('BOM', () => parseAuthorityGrant(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(original.bytes)])));
  reject('depth bound', () => parseAuthorityGrant(Buffer.from('['.repeat(21) + '0' + ']'.repeat(21))));
  reject('collection bound', () => parseAuthorityGrant(Buffer.from('[' + Array(1025).fill('0').join(',') + ']')));
  for (const extension of [null, {}, '', 'reference:grant-counter-work', original.extension + '=', original.extension + '.extra', original.extension.replace('.', '=.'), 'a.' + original.signature]) {
    reject('carriage encoding', () => carriage(extension));
  }
  const padded = Buffer.concat([Buffer.from(original.bytes), Buffer.alloc(16384 - Buffer.byteLength(original.bytes), 32)]);
  checkShape(padded);
  reject('grant over maximum', () => checkShape(Buffer.concat([padded, Buffer.from(' ')])));
  carriage(padded.toString('base64url') + '.' + original.signature);
  reject('selected smaller limit', () => carriage(original.extension, Buffer.byteLength(original.bytes) - 1));
  // Signature component with nonzero unused bits decodes to the same bytes, but is prohibited.
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  const final = original.signature.at(-1), alternate = alphabet[alphabet.indexOf(final) + 1];
  reject('unused signature bits', () => carriage(original.extension.slice(0, -1) + alternate));

  const command = fixture.command;
  assert(validateCore(command), JSON.stringify(validateCore.errors));
  assert(counterProfile.input(command.data.input));
  evidence(command.daspauthority);
  // A generic core schema cannot enforce selected security extensions.
  const absent = structuredClone(command); delete absent.daspauthority;
  assert(validateCore(absent));
  reject('selected missing extension', () => carriage(absent.daspauthority));
  const nested = { ...command, daspauthority: { grant: original.extension } };
  assert.equal(validateCore(nested), false, 'Extension must remain scalar');
  const wrapper = { ...command, type: 'dasp.authorized', data: { command, proof: original.extension } };
  assert.equal(validateCore(wrapper), false, 'Unselected wrapper is not a core plaintext');
  const carrierSchema = ajv.getSchema('https://dasp-protocol.github.io/dasp/schemas/draft-01/bindings/encrypted-carrier.schema.json');
  const carrier = read('conformance/fixtures/encrypted-carriers.json').valid[0];
  assert(carrierSchema(carrier));
  assert.equal(carrierSchema({ ...carrier, daspauthority: original.extension }), false, 'Evidence cannot be an outer carrier attribute');
  // This checks plaintext shape composition only. No HPKE exchange is executed.
  for (const grant of ['standing', 'renewed']) assert(validateCore({ ...command, daspauthority: records.get(grant).extension }));

  const newState = () => ({ admissions: new Map(), grants: new Map(), uses: new Map(), heads: new Map() });
  const decide = (state, step, kind = 'standing') => {
    const extension = step.grant === 'recover' ? 'recover' : records.get(step.grant).extension;
    carriage(extension);
    const { command: data } = step;
    assert(counterProfile.input(data.input), 'Fixture profile input');
    const saved = state.admissions.get(data.command_id);
    if (saved) {
      if (step.can_recover === false) return { error: 'not_found' };
      if (!isDeepStrictEqual(saved.data, data)) return { error: 'conflict' };
      return { disposition: 'duplicate', sequence: saved.sequence };
    }
    if (step.can_submit === false || extension === 'recover') return { error: 'not_found' };
    if (!fixture.selection.commands.some(c => c.name === data.name)) return { error: 'unsupported_command' };
    const { grant: g, B } = evidence(extension);
    const agent = step.agent ?? common.agent, authority = step.authority ?? common.authority;
    if (g.issuer !== common.issuer || g.signing_key !== common.signing_key || step.issuer_allowed === false || g.agent !== agent || g.authority !== authority || g.kind !== kind) return { error: 'not_found' };
    if (step.status === 'unavailable' || step.now === null) return { error: 'unavailable' };
    const now = step.now ?? common.not_before;
    if (step.revoked || now < g.not_before || now >= g.expires_at) return { error: 'not_found' };
    const actor = step.actor ?? 'counter-main', profile = step.profile ?? fixture.selection.profile;
    if (g.kind === 'standing') {
      const s = g.scope, c = s.commands.find(c => c.name === data.name);
      if (s.actor_id !== actor || !isDeepStrictEqual(s.profile, profile) || !c || (s.sessions.mode === 'listed' && !s.sessions.ids.includes(data.session_id))) return { error: 'not_found' };
      if (data.input.amount < c.input_scope.amount_min || data.input.amount > c.input_scope.amount_max) return { error: 'not_found' };
    } else if (!isDeepStrictEqual(g.target, { ...data, actor_id: actor, profile })) return { error: 'not_found' };
    const key = g.issuer + '\0' + g.grant_id, known = state.grants.get(key);
    if (known && !known.equals(B)) return { error: 'not_found' };
    const uses = state.uses.get(key) ?? 0;
    if (g.max_admissions !== undefined && uses >= g.max_admissions) return { error: 'limit_exceeded' };
    const sequence = (state.heads.get(data.session_id) ?? 0) + 1;
    // One recorded commit. This does not exercise transactional persistence or dispatch.
    state.grants.set(key, B); state.uses.set(key, uses + 1);
    state.heads.set(data.session_id, sequence);
    state.admissions.set(data.command_id, { data: structuredClone(data), sequence, grant: step.grant });
    return { disposition: 'accepted', sequence };
  };
  const common = records.get('standing').statement;
  const checkTrace = scenario => {
    const state = newState();
    for (const step of scenario.steps) assert.deepEqual(decide(state, step, scenario.kind), step.expected, `${scenario.id}/${step.id}`);
    const expected = Object.fromEntries(Object.entries(scenario.expected_uses).map(([name, count]) => {
      const g = records.get(name).statement; return [g.issuer + '\0' + g.grant_id, count];
    }));
    assert.deepEqual(Object.fromEntries(state.uses), expected, `${scenario.id}: saved grant uses`);
    assert.equal([...state.uses.values()].reduce((a, b) => a + b, 0), state.admissions.size, 'No orphan use or second charge');
    return state;
  };
  for (const scenario of traces.scenarios) checkTrace(scenario);
  const brokenTrace = structuredClone(traces.scenarios[0]); brokenTrace.steps[4].expected.sequence++;
  reject('trace with wrong duplicate sequence', () => checkTrace(brokenTrace));
  const brokenBudget = structuredClone(traces.scenarios[2]); brokenBudget.expected_uses.budget++;
  reject('trace with retry charged again', () => checkTrace(brokenBudget));

  // Enumerate possible serial commit orders for competing submissions. Not concurrent execution.
  let commitOrders = 0;
  for (const order of [[0, 1], [1, 0]]) {
    const state = newState(), attempts = ['standing', 'renewed'].map(grant => ({ grant, command: command.data }));
    const results = order.map(i => decide(state, attempts[i]));
    assert.deepEqual(results.map(r => r.disposition), ['accepted', 'duplicate']);
    assert.equal(state.admissions.size, 1); assert.equal(state.uses.size, 1); commitOrders++;
  }
  const permutations = values => values.length ? values.flatMap((v, i) => permutations(values.filter((_, j) => j !== i)).map(p => [v, ...p])) : [[]];
  for (const order of permutations([0, 1, 2])) {
    const state = newState();
    const results = order.map(i => decide(state, { grant: 'budget', command: { ...command.data, command_id: `race-${i}`, session_id: i % 2 ? 'session-counter-two' : 'session-counter' } }));
    assert.equal(results.filter(r => r.disposition === 'accepted').length, 2);
    assert.equal(results.filter(r => r.error === 'limit_exceeded').length, 1);
    assert.equal([...state.uses.values()][0], 2); commitOrders++;
  }
  const unbounded = newState();
  for (let i = 0; i < 128; i++) {
    assert.equal(decide(unbounded, { grant: 'standing', command: { ...command.data, command_id: `many-${i}`, session_id: i % 2 ? 'session-counter-two' : 'session-counter' } }).disposition, 'accepted');
  }
  assert.equal(unbounded.admissions.size, 128, 'No implicit standing-grant count limit');
  // Retry equality concerns data only, never a credential, request ID, or encrypted carrier.
  const fresh = { ...command, id: 'fresh-event', requestid: 'fresh-request', daspauthority: records.get('renewed').extension };
  assert.deepEqual(fresh.data, command.data);
  assert(isDeepStrictEqual({ a: 1, b: 2 }, { b: 2, a: 1 }));
  for (const [a, b] of [[{}, { x: null }], [{ x: [] }, { x: {} }], [{ x: [1, 2] }, { x: [2, 1] }], [{ x: 'é' }, { x: 'e\u0301' }]]) assert(!isDeepStrictEqual(a, b));

  return { authoritySignedGrants: fixture.grants.length, authorityRejectedVectors: negativeCount, authorityScenarios: traces.scenarios.length, authorityTraceSteps: traces.scenarios.reduce((n, s) => n + s.steps.length, 0), authorityCommitOrders: commitOrders, authorityUnboundedAdmissions: unbounded.admissions.size };
}
