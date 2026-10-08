import { DASPError, type Json } from "./types.js";

const invalid = (message: string): never => { throw new DASPError("invalid_json", message); };
export const bytes = (value: string): number => new TextEncoder().encode(value).length;
const encodedSizes = new WeakMap<object, number>();
export const encodedSize = (value: object): number | undefined => encodedSizes.get(value);

// Evaluate decimal tokens exactly before JavaScript can round them.
function integer(token: string): number {
  const [mantissa = "", exponent = "0"] = token.toLowerCase().split("e");
  const [whole = "", fraction = ""] = mantissa.replace("-", "").split(".");
  let digits = (whole + fraction).replace(/^0+/, "");
  if (!digits) return 0;
  const scale = Number(exponent) - fraction.length;
  if (scale > 16 || scale < -digits.length) return invalid("Number is outside the portable integer range.");
  if (scale < 0) {
    if (!/^0+$/.test(digits.slice(scale))) return invalid("Fractions must use profile strings.");
    digits = digits.slice(0, scale);
  } else {
    digits += "0".repeat(scale);
  }
  if (digits.length > 16) return invalid("Number is outside the portable integer range.");
  const value = Number((token.startsWith("-") ? "-" : "") + digits);
  if (!Number.isSafeInteger(value)) return invalid("Number is outside the portable integer range.");
  return value;
}

/** Parse bounded JSON. Duplicate keys are rejected, including escaped aliases. */
export function parseJSON(input: string | Uint8Array): Json {
  let source: string;
  try {
    if (typeof input !== "string" && !(input instanceof Uint8Array)) return invalid("Expected JSON text or UTF-8 bytes.");
    if ((typeof input === "string" ? bytes(input) : input.byteLength) > 1_048_576) return invalid("Message exceeds 1048576 bytes.");
    source = typeof input === "string" ? input : new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(input);
  } catch { return invalid("Invalid UTF-8 or message size."); }
  let pos = 0;
  const ws = () => { while (pos < source.length && /[ \t\n\r]/.test(source[pos]!)) pos++; };
  const string = (): string => {
    const start = pos++;
    while (pos < source.length) {
      const ch = source[pos++];
      if (ch === "\\") { pos++; continue; }
      if (ch === '"') {
        let value: string;
        try { value = JSON.parse(source.slice(start, pos)); } catch { return invalid("Invalid JSON string."); }
        if (/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)) return invalid("Invalid Unicode string.");
        return value;
      }
    }
    return invalid("Unclosed JSON string.");
  };
  const value = (depth: number): Json => {
    ws();
    if (depth > 32) return invalid("JSON nesting limit exceeded.");
    const ch = source[pos];
    if (ch === '"') return string();
    if (ch === "{" || ch === "[") {
      const start = pos;
      const object = ch === "{", end = object ? "}" : "]";
      pos++; ws();
      const result: any = object ? Object.create(null) : [];
      let count = 0;
      if (source[pos] === end) { pos++; return result; }
      while (true) {
        if (++count > 1024) return invalid("Container exceeds 1024 entries.");
        ws();
        if (object) {
          if (source[pos] !== '"') return invalid("Object key must be a string.");
          const key = string();
          if (Object.hasOwn(result, key)) return invalid("Duplicate JSON object key.");
          ws();
          if (source[pos++] !== ":") return invalid("Missing colon.");
          result[key] = value(depth + 1);
        } else result.push(value(depth + 1));
        ws();
        if (source[pos] === end) {
          pos++;
          encodedSizes.set(result, bytes(source.slice(start, pos)));
          return result;
        }
        if (source[pos++] !== ",") return invalid("Missing comma.");
      }
    }
    for (const [token, result] of [["true", true], ["false", false], ["null", null]] as const) {
      if (source.startsWith(token, pos)) { pos += token.length; return result; }
    }
    const token = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/.exec(source.slice(pos))?.[0];
    if (!token) return invalid("Invalid JSON value.");
    pos += token.length;
    return integer(token);
  };
  const result = value(0);
  ws();
  if (pos !== source.length) return invalid("Unexpected data after JSON value.");
  return result;
}

/** Reject values that JSON.stringify would change or discard. */
export function jsonText(input: unknown): string {
  const visit = (value: unknown, depth: number): void => {
    if (depth > 32) return invalid("JSON nesting limit exceeded.");
    if (value === null || typeof value === "boolean") return;
    if (typeof value === "string") {
      if (/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)) return invalid("Invalid Unicode string.");
      return;
    }
    if (typeof value === "number" && Number.isSafeInteger(value)) return;
    if (typeof value !== "object" || value === null) return invalid("Value is not portable JSON.");
    if (!Array.isArray(value) && ![Object.prototype, null].includes(Object.getPrototypeOf(value))) return invalid("Use plain JSON objects.");
    if (Reflect.ownKeys(value).some(key => typeof key === "symbol")) return invalid("Symbol keys are not JSON.");
    const keys = Object.keys(value);
    if (Object.getOwnPropertyNames(value).length !== keys.length + (Array.isArray(value) ? 1 : 0)) return invalid("Non-enumerable JSON fields are not supported.");
    if (keys.length > 1024 || (Array.isArray(value) && (keys.length !== value.length || !keys.every((key, index) => key === String(index))))) return invalid("Invalid JSON container.");
    for (const key of keys) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key)!;
      if (!("value" in descriptor)) return invalid("JSON accessors are not supported.");
      visit(key, depth + 1);
      visit(descriptor.value, depth + 1);
    }
  };
  visit(input, 0);
  const encoded = JSON.stringify(input);
  if (bytes(encoded) > 1_048_576) return invalid("Message exceeds 1048576 bytes.");
  return encoded;
}

export function canonical(input: unknown): string {
  if (Array.isArray(input)) return "[" + input.map(canonical).join(",") + "]";
  if (input && typeof input === "object") return "{" + Object.keys(input).sort().map(k => JSON.stringify(k) + ":" + canonical((input as any)[k])).join(",") + "}";
  return JSON.stringify(input);
}
