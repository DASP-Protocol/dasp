export type Json = null | boolean | number | string | Json[] | JsonObject;
export type JsonObject = { [key: string]: Json };
export interface Profile { id: string; version: string }
export interface Session { session_id: string; actor_id: string; profile: Profile }
export interface ProtocolError { code: string; message: string; retryable: boolean }
export type Outcome =
  | { status: "completed"; output: JsonObject; error: null }
  | { status: "failed" | "uncertain"; output: JsonObject | null; error: ProtocolError }
  | { status: "cancelled"; output: JsonObject | null; error: null };
export type Update = { session_id: string; sequence: number } & (
  | { kind: "command.accepted"; command_id: string; payload: { name: string } }
  | { kind: "command.outcome"; command_id: string; payload: Outcome }
  | { kind: "application"; command_id: string | null; payload: { name: string; data: JsonObject } }
);
export interface Data {
  "session.open": Session;
  "session.opened": Session & { cursor: number };
  command: { session_id: string; command_id: string; name: string; input: JsonObject };
  receipt: { session_id: string; command_id: string } & (
    | { disposition: "accepted" | "duplicate"; admission_sequence: number; error: null }
    | { disposition: "rejected"; admission_sequence: null; error: ProtocolError }
  );
  "view.read": { session_id: string };
  view: Session & { cursor: number; state: JsonObject };
  "updates.read": { session_id: string; after: number; limit: number };
  updates: { session_id: string; after: number; next: number; head: number; events: Event<"update">[] };
  "outcome.read": { session_id: string; command_id: string };
  outcome: { session_id: string; command_id: string } & (
    | { state: "pending"; sequence: null; outcome: null }
    | { state: "settled"; sequence: number; outcome: Outcome }
  );
  update: Update;
  progress: { session_id: string; command_id: string | null; name: string; payload: JsonObject };
  "resync.required": { session_id: string; reason: "overflow" | "interrupted"; head: number };
  failure: { error: ProtocolError };
}
export type Kind = keyof Data;
export type Event<K extends Kind = Kind> = K extends Kind ? {
  specversion: "1.0"; id: string; source: string; type: `dasp.${K}.v1`;
  datacontenttype: "application/json"; data: Data[K];
  subject?: string; time?: string; dataschema?: string;
  [extension: string]: unknown;
} & (K extends "update" | "progress" | "resync.required" ? { requestid?: string } : { requestid: string }) : never;
export type ProfileValidator = (event: Event) => boolean;
export type Transport = (request: string, options: { signal: AbortSignal }) => Promise<string | Uint8Array>;
export class DASPError extends Error {
  constructor(public readonly code: string, message: string, public readonly detail?: unknown) {
    super(message);
    this.name = "DASPError";
  }
}
