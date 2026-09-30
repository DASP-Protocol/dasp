import { checkPage } from "./client.js";
import { decode } from "./wire.js";
import { DASPError, type Event, type Transport } from "./types.js";
import { canonical } from "./json.js";

export type DuplexEvent =
  | { kind: "sent" | "received"; wire: string | Uint8Array; event: Event }
  | { kind: "timeout"; requestid: string }
  | { kind: "closed"; error: DASPError };
export interface DuplexOptions {
  hostSource: string;
  /** Hand off one core event. Do not wait for its reply here. */
  send: (wire: string) => void | Promise<void>;
  close: () => void | Promise<void>;
  /** Runs in order. Save changed checkpoints here; do not await new requests. */
  onEvent?: (event: DuplexEvent) => void | Promise<void>;
  maxQueuedMessages?: number;
  maxQueuedBytes?: number;
  maxPendingRequests?: number;
  maxTrackedRequests?: number;
}
type Pending = { event: Event; resolve: (wire: string | Uint8Array) => void;
  reject: (error: DASPError) => void; removeAbort: () => void; observedSent: boolean; receiving: boolean };
const replies: Record<string, string> = {
  "dasp.v1.session.open": "dasp.v1.session.opened", "dasp.v1.command": "dasp.v1.receipt",
  "dasp.v1.view.read": "dasp.v1.view", "dasp.v1.updates.read": "dasp.v1.updates",
  "dasp.v1.outcome.read": "dasp.v1.outcome"
};

/** Request dispatcher for an already authenticated, selected duplex channel.
 * It supplies Client.transport. Feed authenticated/decrypted core JSON to receive.
 * It does not open a socket, establish trust, or implement encryption setup.
 */
export class DuplexTransport {
  private pending = new Map<string, Pending>();
  private seen = new Set<string>();
  private cancelled = new Map<string, string>();
  private tail: Promise<void> = Promise.resolve();
  private queued = 0;
  private bytes = 0;
  private failure: DASPError | null = null;
  private limits: [number, number, number, number];
  constructor(private options: DuplexOptions) {
    this.limits = [options.maxQueuedMessages ?? 100, options.maxQueuedBytes ?? 1_048_576,
      options.maxPendingRequests ?? 100, options.maxTrackedRequests ?? 4096];
    if (typeof options.send !== "function" || typeof options.close !== "function" ||
        typeof options.hostSource !== "string" || !/^[a-z][a-z0-9+.-]*:\S+$/i.test(options.hostSource) ||
        this.limits.some(v => !Number.isSafeInteger(v) || v < 1)) throw new DASPError("configuration", "Invalid duplex options.");
  }
  get closed() { return this.failure !== null; }
  get settled(): Promise<void> { return this.tail; }
  private observe(event: DuplexEvent) {
    if ((event.kind === "sent" || event.kind === "received") && event.wire instanceof Uint8Array) {
      event = { ...event, wire: new Uint8Array(event.wire) };
    }
    return this.options.onEvent?.(event);
  }
  private enqueue(wire: string | Uint8Array, work: () => Promise<void>): Promise<void> {
    if (this.failure) return Promise.reject(this.failure);
    const size = typeof wire === "string" ? new TextEncoder().encode(wire).byteLength : wire.byteLength;
    this.queued++; this.bytes += size;
    if (this.queued > this.limits[0] || this.bytes > this.limits[1]) {
      this.queued--; this.bytes -= size;
      const error = new DASPError("overflow", "Duplex queue limit exceeded."); this.close(error); return Promise.reject(error);
    }
    const result = this.tail.then(async () => { if (this.failure) throw this.failure; await work(); });
    this.tail = result.catch(error => this.close(error instanceof DASPError ? error : new DASPError("transport", "Channel callback failed.")))
      .finally(() => { this.queued--; this.bytes -= size; });
    return result;
  }
  readonly transport: Transport = (wire, { signal }) => {
    if (this.failure) return Promise.reject(this.failure);
    const event = decode(wire), id = event.requestid as string;
    if (!replies[event.type] || this.seen.has(id)) return Promise.reject(new DASPError("correlation", "Invalid or repeated request."));
    if (signal.aborted) return Promise.reject(new DASPError("timeout", "Request was aborted before send."));
    if (this.pending.size >= this.limits[2] || this.seen.size >= this.limits[3]) {
      const error = new DASPError("overflow", "Request tracking limit exceeded."); this.close(error); return Promise.reject(error);
    }
    this.seen.add(id);
    return new Promise((resolve, reject) => {
      const abort = () => {
        const pending = this.pending.get(id); if (!pending) return;
        const error = new DASPError("timeout", "Reply deadline expired.");
        if (event.type === "dasp.v1.session.open") this.close(error);
        else {
          this.cancel([id], error);
          if (pending.observedSent && !pending.receiving) void this.enqueue("", async () => { await this.observe({ kind: "timeout", requestid: id }); }).catch(() => {});
        }
      };
      signal.addEventListener("abort", abort, { once: true });
      this.pending.set(id, { event, resolve, reject, observedSent: false, receiving: false, removeAbort: () => signal.removeEventListener("abort", abort) });
      void this.enqueue(wire, async () => {
        if (!this.pending.has(id)) return;
        this.pending.get(id)!.observedSent = true;
        await this.observe({ kind: "sent", wire, event: structuredClone(event) });
        if (!this.pending.has(id)) return;
        await this.options.send(wire);
      }).catch(error => this.close(error instanceof DASPError ? error : new DASPError("transport", "Channel send failed.")));
    });
  };
  receive(input: string | Uint8Array): Promise<void> {
    const length = typeof input === "string" ? input.length : input.byteLength;
    if (length > 1_048_576 || (typeof input === "string" && new TextEncoder().encode(input).byteLength > 1_048_576)) {
      const error = new DASPError("overflow", "Core message byte limit exceeded."); this.close(error); return Promise.reject(error);
    }
    // Own the bytes while queued; a transport must not mutate them after handoff.
    const wire = typeof input === "string" ? input : new Uint8Array(input);
    return this.enqueue(wire, async () => {
      const event = decode(wire), d: any = event.data;
      if (event.source !== this.options.hostSource) throw new DASPError("correlation", "Unexpected host source.");
      if (["dasp.v1.update", "dasp.v1.progress", "dasp.v1.resync.required"].includes(event.type)) {
        await this.observe({ kind: "received", wire, event: structuredClone(event) }); return;
      }
      const id = event.requestid as string, cancelled = this.cancelled.get(id);
      if (cancelled) {
        if (event.type !== cancelled && event.type !== "dasp.v1.failure") throw new DASPError("correlation", "Invalid cancelled reply type.");
        return;
      }
      const pending = this.pending.get(id);
      if (!pending) throw new DASPError("correlation", "Reply has no pending request.");
      const q: any = pending.event.data;
      if (event.type !== "dasp.v1.failure") {
        if (event.type !== replies[pending.event.type] || d.session_id !== q.session_id ||
            (q.command_id !== undefined && d.command_id !== q.command_id) ||
            (q.actor_id !== undefined && (d.actor_id !== q.actor_id || canonical(d.profile) !== canonical(q.profile)))) {
          throw new DASPError("correlation", "Reply differs from request context.");
        }
        if (event.type === "dasp.v1.updates") {
          checkPage(event, q.after, q.limit);
          if (event.data.events.some(e => e.source !== this.options.hostSource)) throw new DASPError("correlation", "Unexpected saved update source.");
        }
      }
      pending.receiving = true;
      await this.observe({ kind: "received", wire, event: structuredClone(event) });
      // A resync or close in a callback can cancel the request.
      if (this.pending.get(id) === pending && !this.failure) {
        this.pending.delete(id); pending.removeAbort(); pending.resolve(wire);
      }
    });
  }
  cancel(ids: readonly string[], error = new DASPError("resync", "Recovery request was cancelled.")): void {
    for (const id of ids) {
      const pending = this.pending.get(id); if (!pending) continue;
      if (pending.event.type === "dasp.v1.session.open") { this.close(error); return; }
      this.pending.delete(id); this.cancelled.set(id, replies[pending.event.type]!);
      pending.removeAbort(); pending.reject(error);
    }
  }
  close(error = new DASPError("closed", "The channel is closed.")): void {
    if (this.failure) return;
    this.failure = error;
    for (const pending of this.pending.values()) { pending.removeAbort(); pending.reject(error); }
    this.pending.clear();
    void Promise.resolve().then(() => this.options.close()).catch(() => {});
    // Notify after the in-flight event completes, so saved checkpoint order is retained.
    const prior = this.tail;
    void prior.then(() => this.observe({ kind: "closed", error })).catch(() => {});
  }
}
