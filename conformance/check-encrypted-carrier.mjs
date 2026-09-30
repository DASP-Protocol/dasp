import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checkProtocolString, parseProtectedHeader } from './parse-protected-header.mjs';

// Artifact checks only. This is not a wire receiver or a cryptographic verifier.
// Raw protected-header cases check exact tokens and duplicate keys. Outer wire parsing
// and all cryptographic or connection behavior still require separate evidence.
export function checkEncryptedArtifacts(ajv, validateCore) {
  const schema = JSON.parse(readFileSync('specification/draft-01/bindings/encrypted-carrier.schema.json'));
  const fixtures = JSON.parse(readFileSync('conformance/fixtures/encrypted-carriers.json'));
  ajv.addSchema(schema);
  const validateCarrier = ajv.getSchema(schema.$id);
  const validateHeader = ajv.compile({ $ref: schema.$id + '#/$defs/protectedHeader' });
  const attributes = ['specversion', 'id', 'source', 'type', 'datacontenttype'];
  const encode = bytes => Buffer.from(bytes).toString('base64url');
  const decode = (value, minimum, maximum) => {
    assert(/^[A-Za-z0-9_-]+$/.test(value), 'Invalid base64url alphabet');
    const bytes = Buffer.from(value, 'base64url');
    assert.equal(encode(bytes), value, 'Noncanonical base64url');
    assert(bytes.length >= minimum && bytes.length <= maximum, 'Decoded byte bound');
    return bytes;
  };
  const shape = event => {
    assert(validateCarrier(event), JSON.stringify(validateCarrier.errors));
    assert(Buffer.byteLength(JSON.stringify(event)) <= 1410000, 'Compact carrier artifact byte bound');
    const metadata = Object.fromEntries(attributes.map(name => [name, event[name]]));
    for (const value of Object.values(metadata)) checkProtocolString(value);
    assert(Buffer.byteLength(JSON.stringify(metadata)) <= 768, 'Outer metadata byte bound');
    const bytes = decode(event.data.protected, 1, 768);
    const header = parseProtectedHeader(bytes);
    assert(validateHeader(header), JSON.stringify(validateHeader.errors));
    assert.deepEqual(header.envelope, metadata, 'Outer metadata differs from protected copy');
    decode(header.client_challenge, 32, 32);
    decode(header.host_challenge, 32, 32);
    decode(event.data.enc, 32, 32);
    decode(event.data.signature, 64, 64);
    decode(event.data.ciphertext, 16, 1048592);
    return header;
  };

  assert(fixtures.scope.includes('not cryptographically valid'));
  assert.equal(new Set(fixtures.invalid.map(item => item.id)).size, fixtures.invalid.length);
  for (const event of fixtures.valid) {
    shape(event);
    assert.equal(validateCore(event), false, 'Carrier must remain outside the core catalog');
    const reordered = Object.fromEntries(Object.entries(event).reverse());
    shape(reordered);
  }
  for (const item of fixtures.invalid) assert.throws(() => shape(item.event), item.id);

  const rawHeaders = JSON.parse(readFileSync('conformance/fixtures/encrypted-header-vectors.json'));
  assert(rawHeaders.scope.includes('not cryptographically valid'));
  assert.equal(new Set([...rawHeaders.valid, ...rawHeaders.invalid].map(item => item.id)).size,
    rawHeaders.valid.length + rawHeaders.invalid.length);
  const fromHeader = item => {
    const carrier = structuredClone(fixtures.valid[0]);
    Object.assign(carrier, item.metadata);
    carrier.data.protected = encode(item.headerHex ? Buffer.from(item.headerHex, 'hex') : Buffer.from(item.header, 'utf8'));
    return carrier;
  };
  for (const item of rawHeaders.valid) shape(fromHeader(item));
  for (const item of rawHeaders.invalid) assert.throws(() => shape(fromHeader(item)), item.id);

  const event = structuredClone(fixtures.valid[0]);
  const protectedBytes = decode(event.data.protected, 1, 768);
  event.data.protected = encode(Buffer.concat([protectedBytes, Buffer.alloc(768 - protectedBytes.length, 32)]));
  shape(event);
  event.data.protected = encode(Buffer.concat([protectedBytes, Buffer.alloc(769 - protectedBytes.length, 32)]));
  assert.throws(() => shape(event), 'Header one byte above its bound');

  const maximum = structuredClone(fixtures.valid[0]);
  maximum.data.ciphertext = encode(Buffer.alloc(1048592));
  shape(maximum);
  maximum.data.ciphertext = encode(Buffer.alloc(1048593));
  assert.throws(() => shape(maximum), 'Ciphertext one byte above its bound');

  // Code-point limits alone cannot establish a UTF-8 metadata byte bound.
  const unicode = structuredClone(fixtures.valid[0]);
  unicode.id = '\u{1f600}'.repeat(200);
  assert(validateCarrier(unicode));
  assert.throws(() => shape(unicode), 'Metadata UTF-8 byte bound');

  return {
    validCarriers: fixtures.valid.length, invalidCarriers: fixtures.invalid.length,
    validProtectedHeaders: rawHeaders.valid.length, invalidProtectedHeaders: rawHeaders.invalid.length
  };
}
