import { canonical } from "./json.js";
import { decode, encode } from "./wire.js";
import { DASPError, type Data, type Event, type JsonObject, type Kind, type ProfileValidator, type Session, type Transport } from "./types.js";

export interface ClientOptions {
  source: string;
  hostSource: string;
  transport: Transport;
  /** Return true only after checking the selected profile. Exceptions stop the request. */
  validateProfile: ProfileValidator;
  timeoutMs?: number;
}

/** One authenticated host authority. The transport supplies authentication and framing. */
export class Client {
  private readonly options: ClientOptions;
  constructor(options: ClientOptions) {
    this.options = { ...options, timeoutMs: options.timeoutMs ?? 10_000 };
    for (const uri of [options.source, options.hostSource]) {
      if (typeof uri !== "string" || !/^[a-z][a-z0-9+.-]*:\S+$/i.test(uri)) throw new DASPError("configuration", "Use absolute source URIs.");
    }
    if (!Number.isSafeInteger(this.options.timeoutMs) || this.options.timeoutMs! < 1 || this.options.timeoutMs! > 2_147_483_647 ||
        typeof options.transport !== "function" || typeof options.validateProfile !== "function") {
      throw new DASPError("configuration", "Supply a transport, profile validator, and positive timeout.");
    }
  }
  open(session: Session): Promise<Event<"session.opened">> {
    return this.request("session.open", "session.opened", session, session);
  }
  /** Returns an admission receipt, never a completed outcome. No automatic retry. */
  submit(session: Session, command: { command_id: string; name: string; input: JsonObject }): Promise<Event<"receipt">> {
    return this.request("command", "receipt", { ...command, session_id: session.session_id }, session);
  }
  readView(session: Session): Promise<Event<"view">> {
    return this.request("view.read", "view", { session_id: session.session_id }, session);
  }
  readUpdates(session: Session, after: number, limit = 100): Promise<Event<"updates">> {
    return this.request("updates.read", "updates", { session_id: session.session_id, after, limit }, session);
  }
  readOutcome(session: Session, commandId: string): Promise<Event<"outcome">> {
    return this.request("outcome.read", "outcome", { session_id: session.session_id, command_id: commandId }, session);
  }
  private async request<Q extends Kind, R extends Kind>(kind: Q, reply: R, data: Data[Q], session: Session): Promise<Event<R>> {
    // Encode before handing control to asynchronous code. Callers cannot mutate an attempt.
    const request = decode(encode({
      specversion: "1.0", id: crypto.randomUUID(), source: this.options.source,
      type: "dasp." + kind + ".v1", datacontenttype: "application/json",
      requestid: crypto.randomUUID(), data
    } as Event));
    const context = structuredClone(session);
    checkProfile(this.options.validateProfile, request);
    const wire = encode(request);
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    let response: string | Uint8Array;
    try {
      response = await Promise.race([
        Promise.resolve().then(() => this.options.transport(wire, { signal: controller.signal })),
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => {
            reject(new DASPError("timeout", "Reply deadline expired. Command admission may still have occurred."));
            controller.abort();
          }, this.options.timeoutMs);
        })
      ]);
    } catch (error) {
      if (error instanceof DASPError) throw error;
      throw new DASPError("transport", "Transport failed. Command admission may still have occurred.", error);
    } finally { clearTimeout(timer); }
    const event = decode(response);
    if (event.source !== this.options.hostSource || event.requestid !== request.requestid) {
      throw new DASPError("correlation", "Reply source or request ID differs from the request context.");
    }
    if (event.type === "dasp.failure.v1") throw new DASPError("remote_failure", event.data.error.message, event.data.error);
    if (event.type !== "dasp." + reply + ".v1") throw new DASPError("correlation", "Unexpected reply type.");
    const d: any = event.data, q: any = request.data;
    if (d.session_id !== context.session_id ||
        (q.command_id !== undefined && d.command_id !== q.command_id) ||
        (d.actor_id !== undefined && (d.actor_id !== context.actor_id || canonical(d.profile) !== canonical(context.profile)))) {
      throw new DASPError("correlation", "Reply does not match the session, actor, profile, or command.");
    }
    if (event.type === "dasp.updates.v1") {
      checkPage(event, q.after, q.limit);
      for (const update of event.data.events) {
        if (update.source !== this.options.hostSource) throw new DASPError("correlation", "Update producer differs from the host context.");
        checkProfile(this.options.validateProfile, update);
      }
    }
    checkProfile(this.options.validateProfile, event);
    return event as Event<R>;
  }
}

export function checkProfile(validate: ProfileValidator, event: Event): void {
  if (validate(structuredClone(event)) !== true) throw new DASPError("profile", "Event does not match the selected profile.");
}

export function checkPage(event: Event<"updates">, after: number, limit: number): void {
  const d = event.data;
  if (d.after !== after || d.after > d.head || d.events.length > limit ||
      (d.after < d.head && d.events.length === 0)) throw new DASPError("replay", "Invalid replay page bounds.");
  let next = after;
  for (const update of d.events) {
    if (update.data.session_id !== d.session_id || update.data.sequence !== next + 1 || update.data.sequence > d.head) {
      throw new DASPError("replay", "Replay events must be contiguous and in the requested session.");
    }
    next = update.data.sequence;
  }
  if (d.next !== next) throw new DASPError("replay", "Replay next differs from the last update.");
}
