import assert from 'node:assert/strict';

// Artifact helper for this closed two-level header, not a general JSON or wire parser.
// Keep the original bytes for signing; never use this result to re-create signed bytes.
export function checkProtocolString(value) {
  for (const character of value) {
    const point = character.codePointAt(0);
    assert(!(point <= 0x1f || (point >= 0x7f && point <= 0x9f) ||
      (point >= 0xd800 && point <= 0xdfff) || (point >= 0xfdd0 && point <= 0xfdef) ||
      (point & 0xffff) >= 0xfffe), 'Prohibited protocol string character');
  }
}

export function parseProtectedHeader(bytes) {
  assert(bytes.length > 0 && bytes.length <= 768, 'Protected header byte bound');
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  // A BOM is not part of the binding's JSON encoding. TextDecoder otherwise hides it.
  assert(!(bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf), 'Protected header BOM');
  let position = 0;
  const whitespace = () => { while (position < text.length && /[ \t\r\n]/.test(text[position])) position++; };
  const take = character => {
    whitespace();
    assert.equal(text[position++], character, 'Invalid protected JSON syntax');
  };
  const string = () => {
    whitespace();
    const token = text.slice(position).match(/^"(?:[^"\\\u0000-\u001f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"/);
    assert(token, 'Invalid protected JSON string');
    position += token[0].length;
    const value = JSON.parse(token[0]);
    checkProtocolString(value);
    return value;
  };
  const object = depth => {
    assert(depth <= 2, 'Protected header nesting');
    take('{');
    const entries = [], keys = new Set();
    whitespace();
    if (text[position] === '}') { position++; return {}; }
    while (true) {
      const key = string();
      assert(!keys.has(key), 'Duplicate protected JSON key');
      keys.add(key);
      take(':');
      whitespace();
      let value;
      if (text[position] === '"') value = string();
      else if (text[position] === '{') value = object(depth + 1);
      else {
        assert(depth === 1 && key === 'record', 'Invalid protected JSON value');
        const token = text.slice(position).match(/^[0-9]+/)?.[0];
        assert(token && /^[1-9][0-9]*$/.test(token), 'Invalid record integer token');
        position += token.length;
        assert(/[ \t\r\n,}]/.test(text[position] ?? ''), 'Invalid record integer token');
        assert(BigInt(token) <= 9007199254740991n, 'Record integer range');
        value = Number(token);
      }
      entries.push([key, value]);
      whitespace();
      if (text[position] === '}') { position++; return Object.fromEntries(entries); }
      take(',');
    }
  };
  const result = object(1);
  whitespace();
  assert.equal(position, text.length, 'Trailing protected JSON input');
  return result;
}
