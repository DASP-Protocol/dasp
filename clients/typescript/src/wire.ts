import { Ajv2020 } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import schema from "../schema/envelope.schema.json" with { type: "json" };
import { bytes, encodedSize, jsonText, parseJSON } from "./json.js";
import { DASPError, type Event } from "./types.js";

const ajv = new Ajv2020({ strict: false, allErrors: false, ownProperties: true });
(addFormats as unknown as (instance: Ajv2020) => void)(ajv);
const validate = ajv.compile(schema);
const fail = (message: string): never => { throw new DASPError("invalid_event", message); };

function payload(value: unknown, depth = 1): void {
  if (!value || typeof value !== "object") return;
  if (depth > 16) fail("Profile payload exceeds 16 container levels.");
  for (const child of Object.values(value)) if (child && typeof child === "object") payload(child, depth + 1);
}
function strings(value: unknown): void {
  if (typeof value === "string" && bytes(value) > 65_536) fail("Application string exceeds 65536 bytes.");
  if (value && typeof value === "object") for (const [key, child] of Object.entries(value)) { strings(key); strings(child); }
}
function limits(event: Event): void {
  const d: any = event.data;
  if (event.subject !== undefined && d.session_id !== undefined && event.subject !== d.session_id) fail("Subject differs from session_id.");
  strings(d);
  if (event.type === "dasp.update.v1" && (encodedSize(event) ?? bytes(jsonText(event))) > 65_536) fail("Update exceeds 65536 bytes.");
  if (event.type === "dasp.updates.v1") for (const update of event.data.events) limits(update);
  for (const key of ["input", "state", "payload"]) if (Object.hasOwn(d, key)) {
    if (event.type === "dasp.update.v1") {
      if (d.kind === "application") payload(d.payload.data);
      if (d.kind === "command.outcome" && d.payload.output !== null) payload(d.payload.output);
    } else payload(d[key]);
  }
  if (d.outcome?.output !== undefined && d.outcome.output !== null) payload(d.outcome.output);
}
export function decode(input: string | Uint8Array): Event {
  const event = parseJSON(input);
  if (!validate(event)) throw new DASPError("invalid_event", "Event does not match DASP draft-01.", validate.errors);
  if ((event as unknown as Event).type === "dasp.update.v1" &&
      (typeof input === "string" ? bytes(input) : input.byteLength) > 65_536) fail("Update exceeds 65536 bytes.");
  limits(event as unknown as Event);
  return event as unknown as Event;
}
export function encode(event: Event): string {
  const encoded = jsonText(event);
  decode(encoded);
  return encoded;
}
