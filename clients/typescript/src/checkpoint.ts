import { canonical, jsonText } from "./json.js";
import { checkProfile } from "./client.js";
import { decode, encode } from "./wire.js";
import { DASPError, type Event, type JsonObject, type ProfileValidator, type Session } from "./types.js";

export interface Checkpoint {
  session: Session;
  hostSource: string;
  cursor: number;
  state: JsonObject;
  /** Retain evidence with the checkpoint. Missing evidence requires a new trusted view. */
  evidence: Record<string, string>;
}

/** Call only after authenticating and validating the view and selected profile. */
export function checkpointFromView(view: Event<"view">, validateProfile: ProfileValidator): Checkpoint {
  const event = decode(encode(view));
  if (event.type !== "dasp.view.v1") throw new DASPError("checkpoint", "A view is required.");
  checkProfile(validateProfile, event);
  const { session_id, actor_id, profile, cursor, state } = event.data;
  return { session: { session_id, actor_id, profile }, hostSource: event.source, cursor, state, evidence: {} };
}

function identity(event: Event<"update">): string {
  const result: Record<string, unknown> = {};
  for (const key of ["source", "id", "type", "data", "time", "subject", "dataschema"]) {
    if (Object.hasOwn(event, key)) result[key] = event[key];
  }
  return canonical(result);
}

/**
 * Return a new checkpoint only after every update is valid and applied.
 * Save state, cursor, and evidence in one storage transaction before acknowledging delivery.
 */
export function applyUpdates(
  checkpoint: Checkpoint, events: readonly Event<"update">[],
  reduce: (state: JsonObject, event: Event<"update">) => JsonObject,
  validateProfile: ProfileValidator
): Checkpoint {
  if (!Number.isSafeInteger(checkpoint.cursor) || checkpoint.cursor < 0) throw new DASPError("checkpoint", "Invalid applied cursor.");
  const next = structuredClone(checkpoint);
  for (const input of events) {
    const event = decode(encode(input));
    if (event.type !== "dasp.update.v1" || event.source !== next.hostSource || event.data.session_id !== next.session.session_id) {
      throw new DASPError("checkpoint", "Expected an update from the checkpoint session and host.");
    }
    checkProfile(validateProfile, event);
    const sequence = event.data.sequence, proof = identity(event);
    if (sequence <= next.cursor) {
      if (!Object.hasOwn(next.evidence, String(sequence))) throw new DASPError("missing_evidence", "Recover a trusted view before handling this old update.");
      if (next.evidence[sequence] !== proof) throw new DASPError("changed_update", "A saved update changed.");
      continue;
    }
    if (sequence !== next.cursor + 1) throw new DASPError("gap", "Read missing updates before advancing the cursor.");
    const state = reduce(structuredClone(next.state), structuredClone(event));
    if (!state || typeof state !== "object" || Array.isArray(state)) throw new DASPError("checkpoint", "Reducer must return a JSON object.");
    jsonText(state);
    next.state = structuredClone(state);
    next.cursor = sequence;
    next.evidence[sequence] = proof;
  }
  return next;
}
