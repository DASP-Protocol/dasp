> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# TypeScript client plan

Status: planned. No npm package is published by this repository.

Use Promise-based requests and an async subscription interface. Support caller-provided command identifiers. An AbortSignal or request timeout stops the local wait; it does not prove remote cancellation.

Keep revisions as strings on the wire. Use `bigint` or an exact decimal comparison internally; never convert revisions to `number`. Reject unsafe application numbers or require an application string encoding. TypeScript types do not replace runtime message validation.

Bound subscription queues. If consumption cannot keep up, end the connection and recover with new snapshots. Do not silently discard updates while reporting a current view.

Before release, select the supported Node.js and browser versions, choose a browser-compatible authentication profile, add package metadata, and run every shared conformance case. Generated types will follow the shared schema; TypeScript source will not be the protocol source of truth.
