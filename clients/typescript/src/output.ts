import { decode, encode } from "./wire.js";
import { DASPError, type Event } from "./types.js";

export interface OutputQueueOptions {
  maxMessages?: number;
  maxBytes?: number;
  maxSessionMessages?: number;
  maxSessionBytes?: number;
  reservedControlMessages?: number;
  reservedControlBytes?: number;
  maxControlBurst?: number;
}
export interface Delivery {
  token: number;
  sessionId: string;
  wire: string;
  event: Event;
}
type Entry = Delivery & { bytes: number; control: boolean };
const controls = new Set(["dasp.v1.session.opened", "dasp.v1.receipt", "dasp.v1.failure", "dasp.v1.resync.required"]);
const output = new Set([...controls, "dasp.v1.update", "dasp.v1.progress", "dasp.v1.view", "dasp.v1.updates", "dasp.v1.outcome"]);

/** Bounded logical host output. Schedule before delivery encryption. One lease
 * stays charged until complete(); completing a lease proves no remote action.
 * The driver supplies current permission, framing, health checks, and resync.
 */
export class OutputQueue {
  private lanes = new Map<string, Entry[]>();
  private active: Entry | null = null;
  private count = 0;
  private bytes = 0;
  private ordinaryCount = 0;
  private ordinaryBytes = 0;
  private serial = 0;
  private burst = 0;
  private stopped = false;
  private limits: Required<OutputQueueOptions>;
  constructor(options: OutputQueueOptions = {}) {
    const maxMessages = options.maxMessages ?? 128, maxBytes = options.maxBytes ?? 2_097_152;
    this.limits = { maxMessages, maxBytes,
      maxSessionMessages: options.maxSessionMessages ?? Math.min(32, maxMessages),
      maxSessionBytes: options.maxSessionBytes ?? Math.min(524_288, maxBytes),
      reservedControlMessages: options.reservedControlMessages ?? 8,
      reservedControlBytes: options.reservedControlBytes ?? 65_536, maxControlBurst: options.maxControlBurst ?? 8 };
    if (Object.values(this.limits).some(v => !Number.isSafeInteger(v) || v < 1) ||
        this.limits.maxSessionMessages > maxMessages || this.limits.maxSessionBytes > maxBytes ||
        this.limits.reservedControlMessages >= this.limits.maxMessages ||
        this.limits.reservedControlBytes >= this.limits.maxBytes) throw new DASPError("configuration", "Invalid output queue limits.");
  }
  get usage() { return { messages: this.count, bytes: this.bytes }; }
  private available(): void { if (this.stopped) throw new DASPError("closed", "The output queue is closed."); }
  private fits(entry: Entry, old?: Entry): boolean {
    const messages = this.count + 1 - (old ? 1 : 0), bytes = this.bytes + entry.bytes - (old?.bytes ?? 0);
    const session = [...(this.lanes.get(entry.sessionId) ?? [])];
    if (this.active?.sessionId === entry.sessionId) session.push(this.active);
    return messages <= this.limits.maxMessages && bytes <= this.limits.maxBytes &&
      session.length + 1 - (old ? 1 : 0) <= this.limits.maxSessionMessages &&
      session.reduce((sum, item) => sum + item.bytes, 0) + entry.bytes - (old?.bytes ?? 0) <= this.limits.maxSessionBytes &&
      (entry.control || (this.ordinaryCount + 1 - (old ? 1 : 0) <= this.limits.maxMessages - this.limits.reservedControlMessages &&
        this.ordinaryBytes + entry.bytes - (old?.bytes ?? 0) <= this.limits.maxBytes - this.limits.reservedControlBytes));
  }
  private charge(entry: Entry, direction: 1 | -1): void {
    this.count += direction; this.bytes += direction * entry.bytes;
    if (!entry.control) { this.ordinaryCount += direction; this.ordinaryBytes += direction * entry.bytes; }
  }
  /** False means only temporary progress was dropped. Saved data or replies
   * that exceed capacity throw overflow; the driver must resync or close.
   * A failure has no core session_id, so supply its correlated session here.
   */
  enqueue(value: Event, failureSessionId?: string): boolean {
    this.available();
    const wire = encode(value), event = decode(wire);
    if (!output.has(event.type)) throw new DASPError("configuration", "The queue accepts host output only.");
    const sessionId = event.type === "dasp.v1.failure" ? failureSessionId : (event.data as { session_id: string }).session_id;
    if (typeof sessionId !== "string" || !/^[A-Za-z0-9._:-]{1,128}$/.test(sessionId)) throw new DASPError("configuration", "Supply the output session identity.");
    if (this.serial === Number.MAX_SAFE_INTEGER) throw new DASPError("overflow", "Output lease identities are exhausted.");
    const entry: Entry = { token: this.serial + 1, sessionId, wire, event,
      bytes: new TextEncoder().encode(wire).byteLength, control: controls.has(event.type) };
    const lane = this.lanes.get(sessionId) ?? [], last = lane.at(-1);
    const replace = event.type === "dasp.v1.progress" && last?.event.type === "dasp.v1.progress" &&
      event.data.command_id === last.event.data.command_id && event.data.name === last.event.data.name ? last : undefined;
    if (!this.fits(entry, replace)) {
      if (event.type === "dasp.v1.progress") return false;
      throw new DASPError("overflow", "Output capacity exceeded; resync or close is required.");
    }
    this.serial++;
    if (replace) { this.charge(replace, -1); lane.pop(); }
    lane.push(entry); this.lanes.set(sessionId, lane); this.charge(entry, 1);
    return true;
  }
  /** One active write. Choose control heads first with a finite burst, rotate
   * sessions fairly, and preserve every session's original enqueue order.
   */
  take(): Delivery | null {
    this.available();
    if (this.active || this.lanes.size === 0) return null;
    const heads = [...this.lanes.entries()], control = heads.find(([, lane]) => lane[0]!.control),
      ordinary = heads.find(([, lane]) => !lane[0]!.control);
    const [id, lane] = (control && (!ordinary || this.burst < this.limits.maxControlBurst) ? control : ordinary)!;
    const entry = lane.shift()!;
    this.lanes.delete(id); if (lane.length) this.lanes.set(id, lane);
    this.active = entry; this.burst = entry.control ? Math.min(this.burst + 1, this.limits.maxControlBurst) : 0;
    return { token: entry.token, sessionId: entry.sessionId, wire: entry.wire, event: structuredClone(entry.event) };
  }
  /** Call only after a known write result or a known undispatched discard. */
  complete(token: number): void {
    this.available();
    if (!this.active || this.active.token !== token) throw new DASPError("configuration", "Output lease does not match the active write.");
    this.charge(this.active, -1); this.active = null;
  }
  /** Drop unsent attachment output before resync. Direct replies are retained.
   * The driver must separately handle any leased event at its release boundary.
   */
  discardUpdates(sessionId: string): number {
    this.available();
    const lane = this.lanes.get(sessionId); if (!lane) return 0;
    const kept = lane.filter(entry => {
      if (entry.event.type !== "dasp.v1.update" && entry.event.type !== "dasp.v1.progress") return true;
      this.charge(entry, -1); return false;
    });
    if (kept.length) this.lanes.set(sessionId, kept); else this.lanes.delete(sessionId);
    return lane.length - kept.length;
  }
  close(): void {
    this.stopped = true; this.lanes.clear(); this.active = null;
    this.count = this.bytes = this.ordinaryCount = this.ordinaryBytes = 0;
  }
}
