import { applyUpdates, type Checkpoint } from "./checkpoint.js";
import { checkPage, checkProfile } from "./client.js";
import { canonical } from "./json.js";
import { decode, encode } from "./wire.js";
import { DASPError, type Event, type JsonObject, type ProfileValidator } from "./types.js";

export interface LiveOptions {
  checkpoint: Checkpoint;
  clientSource: string;
  validateProfile: ProfileValidator;
  reduce: (state: JsonObject, event: Event<"update">) => JsonObject;
  pageLimit?: number;
  maxBufferedEvents?: number;
  maxBufferedBytes?: number;
  maxTrackedRequests?: number;
}
type Pending = { event: Event; replay: boolean };
const replies: Record<string, string> = {
  "dasp.v1.session.open": "dasp.v1.session.opened", "dasp.v1.command": "dasp.v1.receipt",
  "dasp.v1.view.read": "dasp.v1.view", "dasp.v1.updates.read": "dasp.v1.updates",
  "dasp.v1.outcome.read": "dasp.v1.outcome"
};

/** Immutable transitions for one session on an authenticated, selected connection.
 * Serialize sent/received transitions. Save a changed checkpoint before installing
 * the returned recovery state. On an exception, close the entire connection.
 */
export class LiveRecovery {
  private options: Required<Omit<LiveOptions, "checkpoint">>;
  private saved: Checkpoint;
  private currentPhase: "inactive" | "opening" | "replay" | "live" | "closed" = "inactive";
  private boundary: number | null = null;
  private push: number | null = null;
  private pending = new Map<string, Pending>();
  private seen = new Set<string>();
  private cancelled = new Set<string>();
  private buffer: Event<"update">[] = [];
  private bufferBytes = 0;
  private effect: "none" | "reply" | "save" | "discard" | "progress" | "reopen" | "wait-open" | "close" = "none";

  constructor(options: LiveOptions) {
    this.options = { clientSource: options.clientSource, reduce: options.reduce,
      validateProfile: options.validateProfile, pageLimit: options.pageLimit ?? 100,
      maxBufferedEvents: options.maxBufferedEvents ?? 100,
      maxBufferedBytes: options.maxBufferedBytes ?? 1_048_576,
      maxTrackedRequests: options.maxTrackedRequests ?? 4096 };
    if (typeof options.reduce !== "function" || typeof options.validateProfile !== "function" ||
        Object.values(this.options).some(v => typeof v === "number" && (!Number.isSafeInteger(v) || v < 1)) ||
        this.options.pageLimit > 100) throw new DASPError("configuration", "Invalid live recovery options.");
    const cp = options.checkpoint;
    decode(encode({ specversion: "1.0", id: "checkpoint", source: cp.hostSource,
      type: "dasp.v1.view", datacontenttype: "application/json", requestid: "checkpoint",
      data: { ...cp.session, cursor: cp.cursor, state: cp.state } }));
    decode(encode({ specversion: "1.0", id: "context", source: options.clientSource,
      type: "dasp.v1.session.open", datacontenttype: "application/json", requestid: "context", data: cp.session }));
    if (!cp.evidence || typeof cp.evidence !== "object" || Array.isArray(cp.evidence) ||
        Object.values(cp.evidence).some(v => typeof v !== "string")) {
      throw new DASPError("checkpoint", "Invalid duplicate evidence.");
    }
    this.saved = structuredClone(cp);
  }
  get checkpoint(): Checkpoint { return structuredClone(this.saved); }
  get phase() { return this.currentPhase; }
  get target() { return this.boundary; }
  get nextPush() { return this.push; }
  get action() { return this.effect; }
  get cancelledRequests(): readonly string[] { return [...this.cancelled]; }
  get pendingOpen(): string | undefined {
    return [...this.pending].find(([, p]) => p.event.type === "dasp.v1.session.open")?.[0];
  }
  private active() { return this.currentPhase === "replay" || this.currentPhase === "live"; }
  private copy(): LiveRecovery {
    const next = Object.assign(Object.create(LiveRecovery.prototype), this) as LiveRecovery;
    next.pending = new Map(this.pending); next.seen = new Set(this.seen);
    next.cancelled = new Set(this.cancelled); next.buffer = [...this.buffer]; next.effect = "none";
    return next;
  }
  private fail(code: string, message: string): never { throw new DASPError(code, message); }

  /** Track the actual outgoing event before handing it to the channel.
   * Mark only recovery reads with replay:true. Ordinary explicit reads stay valid.
   */
  sent(wire: string | Uint8Array, options: { replay?: boolean } = {}): LiveRecovery {
    if (this.phase === "closed") this.fail("closed", "The connection is closed.");
    const event = decode(wire), d: any = event.data;
    if (!replies[event.type] || event.source !== this.options.clientSource || d.session_id !== this.saved.session.session_id) {
      this.fail("correlation", "Request differs from the live session context.");
    }
    const id = event.requestid as string;
    if (this.seen.has(id)) this.fail("correlation", "Request ID was already used on this connection.");
    if (this.seen.size >= this.options.maxTrackedRequests) this.fail("overflow", "Request tracking limit reached; reconnect.");
    const next = this.copy();
    if (event.type === "dasp.v1.session.open") {
      if (this.pendingOpen) this.fail("live", "Only one open can be pending for this session.");
      if (!this.active()) next.currentPhase = "opening";
    }
    if (options.replay) {
      if (event.type !== "dasp.v1.updates.read" || this.phase !== "replay" ||
          [...this.pending.values()].some(p => p.replay) || d.after !== this.saved.cursor || d.limit > this.options.pageLimit) {
        this.fail("replay", "Invalid recovery read or another recovery read is pending.");
      }
    }
    checkProfile(this.options.validateProfile, event);
    next.seen.add(id); next.pending.set(id, { event, replay: options.replay === true });
    return next;
  }

  /** Feed original core JSON only after channel authentication and decryption. */
  received(wire: string | Uint8Array): LiveRecovery {
    if (this.phase === "closed") this.fail("closed", "The connection is closed.");
    const event = decode(wire), d: any = event.data;
    if (event.source !== this.saved.hostSource) this.fail("correlation", "Unexpected host source.");
    const next = this.copy();
    // Push request IDs have no correlation meaning.
    if (["dasp.v1.update", "dasp.v1.progress", "dasp.v1.resync.required"].includes(event.type)) {
      if (!this.active() || d.session_id !== this.saved.session.session_id) this.fail("live", "Push has no active attachment.");
      checkProfile(this.options.validateProfile, event);
      if (event.type === "dasp.v1.resync.required") {
        next.currentPhase = "inactive"; next.buffer = []; next.bufferBytes = 0;
        for (const [id, pending] of next.pending) if (pending.replay) {
          next.cancelled.add(id); next.pending.delete(id);
        }
        next.effect = next.pendingOpen ? "wait-open" : "reopen";
      } else if (event.type === "dasp.v1.progress") next.effect = "progress";
      else {
        if (d.sequence !== this.push) this.fail("gap", "Live push sequence has a gap or repeat.");
        next.push = d.sequence + 1;
        if (this.phase === "replay") {
          next.buffer.push(event as Event<"update">);
          next.bufferBytes += new TextEncoder().encode(encode(event)).byteLength;
          if (next.buffer.length > this.options.maxBufferedEvents || next.bufferBytes > this.options.maxBufferedBytes) {
            this.fail("overflow", "Live recovery buffer limit exceeded; close the connection.");
          }
        } else {
          next.saved = applyUpdates(this.saved, [event as Event<"update">], this.options.reduce, this.options.validateProfile);
          next.effect = next.saved.cursor === this.saved.cursor ? "none" : "save";
        }
      }
      return next;
    }
    const id = event.requestid as string;
    if (this.cancelled.has(id)) {
      if (event.type !== "dasp.v1.updates" && event.type !== "dasp.v1.failure") this.fail("correlation", "Invalid cancelled replay reply type.");
      next.effect = "discard"; return next;
    }
    const pending = this.pending.get(id);
    if (!pending) this.fail("correlation", "Reply has no pending request.");
    next.pending.delete(id); next.effect = "reply";
    if (event.type === "dasp.v1.failure") {
      if (pending.event.type === "dasp.v1.session.open" && !this.active()) next.currentPhase = "inactive";
      return next;
    }
    const q: any = pending.event.data;
    if (event.type !== replies[pending.event.type] || d.session_id !== q.session_id ||
        (q.command_id !== undefined && d.command_id !== q.command_id)) this.fail("correlation", "Reply differs from request context.");
    checkProfile(this.options.validateProfile, event);
    if (event.type === "dasp.v1.session.opened") {
      const { cursor: head, ...tuple } = d;
      if (canonical(tuple) !== canonical(q) || canonical(tuple) !== canonical(this.saved.session)) {
        this.fail("correlation", "Open reply changed the session tuple.");
      }
      if (!this.active()) {
        if (head < this.saved.cursor) this.fail("continuity", "Host head is below the saved applied cursor.");
        next.boundary = head; next.push = head + 1;
        next.currentPhase = this.saved.cursor < head ? "replay" : "live";
      }
    } else if (event.type === "dasp.v1.updates") {
      checkPage(event, q.after, q.limit);
      for (const update of event.data.events) {
        if (update.source !== this.saved.hostSource) this.fail("correlation", "Unexpected saved update source.");
        checkProfile(this.options.validateProfile, update);
      }
      if (pending.replay) {
        if (this.phase !== "replay" || d.head < this.boundary!) this.fail("continuity", "Replay lost its captured history boundary.");
        next.saved = applyUpdates(this.saved, event.data.events, this.options.reduce, this.options.validateProfile);
        if (next.saved.cursor >= this.boundary!) {
          next.saved = applyUpdates(next.saved, this.buffer, this.options.reduce, this.options.validateProfile);
          next.buffer = []; next.bufferBytes = 0; next.currentPhase = "live";
        }
        if (next.saved.cursor !== this.saved.cursor) next.effect = "save";
      }
    } else if (event.type === "dasp.v1.view" &&
        (d.actor_id !== this.saved.session.actor_id || canonical(d.profile) !== canonical(this.saved.session.profile))) {
      this.fail("correlation", "View changed the session tuple.");
    }
    return next;
  }

  nextRead(): { session_id: string; after: number; limit: number } | null {
    if (this.phase !== "replay" || [...this.pending.values()].some(p => p.replay)) return null;
    return { session_id: this.saved.session.session_id, after: this.saved.cursor,
      limit: Math.min(this.options.pageLimit, this.boundary! - this.saved.cursor) };
  }
  timeout(requestid: string): LiveRecovery {
    const pending = this.pending.get(requestid);
    if (!pending) this.fail("correlation", "Timeout has no pending request.");
    if (pending.event.type === "dasp.v1.session.open") return this.close();
    const next = this.copy(); next.pending.delete(requestid);
    if (pending.replay) next.cancelled.add(requestid);
    return next;
  }
  close(): LiveRecovery {
    const next = this.copy(); next.currentPhase = "closed"; next.effect = "close";
    next.pending.clear(); next.buffer = []; next.bufferBytes = 0; return next;
  }
}
