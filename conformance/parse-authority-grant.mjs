import assert from 'node:assert/strict';

// Bounded artifact parser for signed grant vectors. This is not a binding receiver.
// Original bytes, rather than this parsed object, are the signature input.
export function parseAuthorityGrant(bytes, maximum = 16384) {
  assert(bytes.length > 0 && bytes.length <= maximum, 'Grant byte bound');
  assert(!(bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf), 'Grant BOM');
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  let position = 0;
  const space = () => { while (/[ \t\r\n]/.test(text[position] ?? '') && position < text.length) position++; };
  const take = character => { space(); assert.equal(text[position++], character, 'Grant JSON syntax'); };
  const string = () => {
    space();
    const token = text.slice(position).match(/^"(?:[^"\\\u0000-\u001f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"/);
    assert(token, 'Grant JSON string');
    position += token[0].length;
    const result = JSON.parse(token[0]);
    for (const c of result) assert(!(c.codePointAt(0) >= 0xd800 && c.codePointAt(0) <= 0xdfff), 'Unpaired surrogate');
    return result;
  };
  const value = depth => {
    space();
    if (text[position] === '"') return string();
    if (text[position] === '{' || text[position] === '[') {
      assert(depth <= 20, 'Grant container depth');
      const object = text[position++] === '{', end = object ? '}' : ']';
      const entries = [], keys = new Set();
      space();
      if (text[position] === end) { position++; return object ? {} : []; }
      while (true) {
        assert(entries.length < 1024, 'Grant collection bound');
        if (object) {
          const key = string();
          assert(!keys.has(key), 'Duplicate grant JSON key');
          keys.add(key); take(':'); entries.push([key, value(depth + 1)]);
        } else entries.push(value(depth + 1));
        space();
        if (text[position] === end) { position++; return object ? Object.fromEntries(entries) : entries; }
        take(',');
      }
    }
    for (const [literal, decoded] of [['true', true], ['false', false], ['null', null]]) {
      if (text.startsWith(literal, position)) { position += literal.length; return decoded; }
    }
    const token = text.slice(position).match(/^-?(?:0|[1-9][0-9]*)/)?.[0];
    assert(token && /^(0|-?[1-9][0-9]*)$/.test(token), 'Grant integer token');
    position += token.length;
    assert(position === text.length || /[ \t\r\n,}\]]/.test(text[position]), 'Grant integer token');
    const integer = BigInt(token);
    assert(integer >= -9007199254740991n && integer <= 9007199254740991n, 'Grant integer range');
    return Number(token);
  };
  const result = value(1);
  space();
  assert.equal(position, text.length, 'Trailing grant JSON');
  return result;
}
