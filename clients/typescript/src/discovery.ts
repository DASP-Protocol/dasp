import { Buffer } from "node:buffer";
import { createHash, type Hash } from "node:crypto";
import { Ajv2020 } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import controlSchema from "../schema/capability-discovery.schema.json" with { type: "json" };
import { bytes, jsonText, parseJSON } from "./json.js";
import { DASPError } from "./types.js";

export const DISCOVERY_CONTRACT = "https://dasp-protocol.github.io/dasp/contracts/capability-discovery" as const;
export const DISCOVERY_VERSION = "draft-01" as const;
export const JSON_SCHEMA_2020_12 = "https://json-schema.org/draft/2020-12/schema" as const;
export const SCHEMA_MEDIA_TYPE = "application/schema+json" as const;

export type DiscoveryOperation =
  | "capabilities.list"
  | "capabilities.get"
  | "capabilities.resource.read"
  | "capabilities.snapshot.release";
export type DiscoveryFailureCode =
  | "unsupported_contract"
  | "invalid_request"
  | "unavailable"
  | "invalid_continuation"
  | "stale_snapshot"
  | "request_limit"
  | "item_too_large"
  | "view_too_large"
  | "snapshot_capacity"
  | "resource_unavailable"
  | "contract_violation";

export interface DiscoveryLimits {
  page_items: number;
  view_items: number;
  detail_items: number;
  control_bytes: number;
  presentation_bytes: number;
  resource_bytes: number;
  closure_resources: number;
  closure_bytes: number;
  opaque_bytes: number;
  live_snapshots: number;
  snapshot_retention_ms: number;
}
export interface ActorProfileDescriptor {
  uri: string;
  version: string;
  content_ref: string;
  core: { id: string; version: string; content_ref: string };
}
export interface CapabilityIdentity {
  profile_uri: string;
  profile_version: string;
  command: string;
}
export interface CapabilitySummary {
  capability: CapabilityIdentity;
  profile_requirement: "required" | "optional";
  label?: string;
  description?: string;
}
export interface ResourceDigest {
  algorithm: "sha-256";
  media_type: typeof SCHEMA_MEDIA_TYPE;
  value: string;
}
export interface ResourceDescriptor {
  resource: string;
  media_type: typeof SCHEMA_MEDIA_TYPE;
  dialect: string;
  schema_id?: string;
  byte_length: number;
  digest?: ResourceDigest;
}
export interface SchemaManifestDocument {
  input_root: string;
  output_root: string;
  resources: ResourceDescriptor[];
  vocabularies: Array<{ uri: string; required: boolean }>;
  closed: true;
}
export interface CapabilityDetail extends CapabilitySummary { schemas: SchemaManifestDocument }

type NonEmptyArray<T> = [T, ...T[]];

interface DiscoveryBase<O extends DiscoveryOperation, K extends "request" | "reply" | "failure"> {
  contract: typeof DISCOVERY_CONTRACT;
  version: typeof DISCOVERY_VERSION;
  operation: O;
  kind: K;
}
export type ListStartRequest = DiscoveryBase<"capabilities.list", "request"> & {
  start: string;
  actor: string;
  limits: DiscoveryLimits;
  advertised_view?: { type: string; value: string };
};
export type ListContinuationRequest = DiscoveryBase<"capabilities.list", "request"> & { continuation: string };
type ListReplyBase = DiscoveryBase<"capabilities.list", "reply"> & {
  actor: string;
  profile: ActorProfileDescriptor;
  snapshot: string;
  resolved_view: string;
  page: string;
};
export type ListReply = ListReplyBase & (
  | { summaries: CapabilitySummary[]; complete: true; continuation?: never }
  | { summaries: NonEmptyArray<CapabilitySummary>; complete: false; continuation: string }
);
export type GetRequest = DiscoveryBase<"capabilities.get", "request"> & {
  snapshot: string;
  capabilities: CapabilityIdentity[];
};
export type GetReply = DiscoveryBase<"capabilities.get", "reply"> & {
  profile: ActorProfileDescriptor;
  snapshot: string;
  resolved_view: string;
  details: CapabilityDetail[];
};
export type ResourceReadRequest = DiscoveryBase<"capabilities.resource.read", "request"> & {
  snapshot: string;
  resource: string;
};
export type ResourceReadReply = DiscoveryBase<"capabilities.resource.read", "reply"> & {
  snapshot: string;
  resource: ResourceDescriptor;
};
export type SnapshotReleaseRequest = DiscoveryBase<"capabilities.snapshot.release", "request"> & { snapshot: string };
export type SnapshotReleaseReply = DiscoveryBase<"capabilities.snapshot.release", "reply"> & {
  snapshot: string;
  released: true;
};
export interface DiscoveryLimitDetail {
  name: keyof DiscoveryLimits;
  maximum: number;
  actual?: number;
}
export type DiscoveryLimitFailureCode =
  | "request_limit"
  | "item_too_large"
  | "view_too_large"
  | "snapshot_capacity";
type DiscoveryFailureFields =
  | { code: DiscoveryLimitFailureCode; limit?: DiscoveryLimitDetail }
  | { code: Exclude<DiscoveryFailureCode, DiscoveryLimitFailureCode>; limit?: never };
export type DiscoveryFailure = {
  [O in DiscoveryOperation]: DiscoveryBase<O, "failure"> & DiscoveryFailureFields
}[DiscoveryOperation];
export type DiscoveryDocument =
  | ListStartRequest
  | ListContinuationRequest
  | ListReply
  | GetRequest
  | GetReply
  | ResourceReadRequest
  | ResourceReadReply
  | SnapshotReleaseRequest
  | SnapshotReleaseReply
  | DiscoveryFailure;
export type DiscoveryRequest = ListStartRequest | ListContinuationRequest | GetRequest | ResourceReadRequest | SnapshotReleaseRequest;

let compiledValidators: {
  control: ReturnType<Ajv2020["compile"]>;
  manifest: ReturnType<Ajv2020["compile"]>;
  resource: ReturnType<Ajv2020["compile"]>;
} | undefined;

const validators = () => {
  if (compiledValidators) return compiledValidators;
  const ajv = new Ajv2020({ strict: false, allErrors: false, ownProperties: true });
  (addFormats as unknown as (instance: Ajv2020) => void)(ajv);
  const schemaId = (controlSchema as { $id: string }).$id;
  compiledValidators = {
    control: ajv.compile(controlSchema),
    manifest: ajv.compile({ $ref: `${schemaId}#/$defs/schemaManifest` }),
    resource: ajv.compile({ $ref: `${schemaId}#/$defs/resourceDescriptor` })
  };
  return compiledValidators;
};

const fail = (code: string, message: string, detail?: unknown): never => {
  throw new DASPError(code, message, detail);
};
const utf8 = (value: string): Uint8Array => new TextEncoder().encode(value);
const asBytes = (value: string | Uint8Array): Uint8Array => typeof value === "string" ? utf8(value) : value;
const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const exactProfile = (left: ActorProfileDescriptor, right: ActorProfileDescriptor): boolean =>
  left.uri === right.uri && left.version === right.version && left.content_ref === right.content_ref &&
  left.core.id === right.core.id && left.core.version === right.core.version &&
  left.core.content_ref === right.core.content_ref;
const capabilityKey = (identity: CapabilityIdentity): string =>
  JSON.stringify([identity.profile_uri, identity.profile_version, identity.command]);
const ensureProfile = (identity: CapabilityIdentity, profile: ActorProfileDescriptor): void => {
  if (identity.profile_uri !== profile.uri || identity.profile_version !== profile.version)
    fail("contract_violation", "Capability identity differs from the snapshot profile.");
};
const controlBytes = (input: unknown): number => {
  if (typeof input === "string") return bytes(input);
  if (input instanceof Uint8Array) return input.byteLength;
  return bytes(jsonText(input));
};
const discoveryLimitNames = [
  "page_items", "view_items", "detail_items", "control_bytes", "presentation_bytes",
  "resource_bytes", "closure_resources", "closure_bytes", "opaque_bytes", "live_snapshots",
  "snapshot_retention_ms"
] as const satisfies readonly (keyof DiscoveryLimits)[];
const positiveSafeInteger = (value: number, name: string): number => {
  if (!Number.isSafeInteger(value) || value < 1)
    fail("invalid_request", `${name} must be a positive safe integer.`);
  return value;
};
const stricterLimits = (
  selected: DiscoveryLimits | undefined,
  local: DiscoveryLimits | undefined
): DiscoveryLimits | undefined => {
  if (!selected && !local) return undefined;
  const source = selected ?? local!;
  const result = structuredClone(source);
  for (const name of discoveryLimitNames) {
    positiveSafeInteger(source[name], `Discovery limit ${name}`);
    if (local) {
      positiveSafeInteger(local[name], `Discovery limit ${name}`);
      result[name] = Math.min(result[name], local[name]);
    }
  }
  return result;
};
const localBound = (value: number | undefined, ceiling: number, name: string): number =>
  value === undefined ? ceiling : Math.min(positiveSafeInteger(value, name), ceiling);
const safeSum = (left: number, right: number): number =>
  left > Number.MAX_SAFE_INTEGER - right ? Number.MAX_SAFE_INTEGER : left + right;
const safeProduct = (left: number, right: number): number =>
  left > Math.floor(Number.MAX_SAFE_INTEGER / right) ? Number.MAX_SAFE_INTEGER : left * right;
const exceedsTotal = (current: number, increment: number, maximum: number): boolean =>
  current > maximum || increment > maximum - current;
const enforceControlBytes = (input: unknown, maximum: number, code: string, label: string): void => {
  if (controlBytes(input) > maximum) fail(code, `${label} exceeds the selected control-byte limit.`);
};
const enforceOpaqueBytes = (values: Iterable<string | undefined>, maximum: number, code: string): void => {
  for (const value of values)
    if (value !== undefined && bytes(value) > maximum)
      fail(code, "Discovery opaque value exceeds the selected byte limit.");
};

/** Validate one closed discovery control document. Text input is parsed with duplicate-key checks. */
export function validateDiscovery(input: unknown): DiscoveryDocument {
  const document = typeof input === "string" || input instanceof Uint8Array ? parseJSON(input) : input;
  const validate = validators().control;
  if (!validate(document))
    fail("invalid_request", "Invalid capability-discovery control document.", validate.errors);
  return document as DiscoveryDocument;
}

/** Build and validate one discovery control document. */
export function discoveryDocument<O extends DiscoveryOperation, K extends "request" | "reply" | "failure">(
  operation: O,
  kind: K,
  fields: Record<string, unknown>
): Extract<DiscoveryDocument, { operation: O; kind: K }> {
  return validateDiscovery({ ...fields, contract: DISCOVERY_CONTRACT, version: DISCOVERY_VERSION, operation, kind }) as
    Extract<DiscoveryDocument, { operation: O; kind: K }>;
}

export interface EnumerationOptions {
  accumulate?: boolean;
  limits?: DiscoveryLimits;
  expectedActor?: string;
  maxPages?: number;
  maxItems?: number;
  maxControlBytes?: number;
  onPage?: (page: ListReply) => void;
  onSummary?: (summary: CapabilitySummary) => void;
}

/** Incremental validation state for summary pages. */
export class DiscoveryEnumeration {
  #actor?: string;
  #profile?: ActorProfileDescriptor;
  #snapshot?: string;
  #resolvedView?: string;
  #pageCount = 0;
  #itemCount = 0;
  #receivedControlBytes = 0;
  #complete = false;
  #continuation?: string;
  readonly #capabilities = new Set<string>();
  readonly #limits?: DiscoveryLimits;
  readonly #pages = new Set<string>();
  readonly #continuations = new Set<string>();
  readonly #collected?: CapabilitySummary[];
  readonly #options: EnumerationOptions;
  readonly #expectedActor?: string;
  #lastCommand?: string;

  constructor(options: EnumerationOptions = {}) {
    if (options.accumulate !== undefined && typeof options.accumulate !== "boolean")
      fail("invalid_request", "The accumulate option must be boolean.");
    if (options.expectedActor !== undefined && (typeof options.expectedActor !== "string" || options.expectedActor.length === 0))
      fail("invalid_request", "The expected actor must be a nonempty string.");
    for (const [name, value] of [
      ["maxPages", options.maxPages],
      ["maxItems", options.maxItems],
      ["maxControlBytes", options.maxControlBytes]
    ] as const)
      if (value !== undefined) positiveSafeInteger(value, name);
    this.#options = { ...options, limits: options.limits ? structuredClone(options.limits) : undefined };
    this.#limits = this.#options.limits;
    this.#expectedActor = options.expectedActor;
    if (options.accumulate) this.#collected = [];
  }

  get actor(): string | undefined { return this.#actor; }
  get profile(): ActorProfileDescriptor | undefined {
    return this.#profile ? structuredClone(this.#profile) : undefined;
  }
  get snapshot(): string | undefined { return this.#snapshot; }
  get resolvedView(): string | undefined { return this.#resolvedView; }
  get pageCount(): number { return this.#pageCount; }
  get itemCount(): number { return this.#itemCount; }
  get receivedControlBytes(): number { return this.#receivedControlBytes; }
  get complete(): boolean { return this.#complete; }
  get continuation(): string | undefined { return this.#continuation; }
  get capabilities(): ReadonlySet<string> { return new Set(this.#capabilities); }
  get limits(): DiscoveryLimits | undefined {
    return this.#limits ? structuredClone(this.#limits) : undefined;
  }

  hasCapability(identity: CapabilityIdentity): boolean {
    return this.#capabilities.has(capabilityKey(identity));
  }

  push(input: unknown): ListReply {
    const encodedBytes = controlBytes(input);
    const document = validateDiscovery(input);
    if (document.operation !== "capabilities.list")
      fail("invalid_request", "Expected a capabilities.list reply.");
    if (document.kind === "failure") {
      if (this.#limits && encodedBytes > this.#limits.control_bytes)
        fail("contract_violation", "Discovery failure exceeds the selected byte limit.");
      fail(document.code, `Capability discovery failed with ${document.code}.`, structuredClone(document));
    }
    if (document.kind !== "reply") fail("invalid_request", "Expected a capabilities.list reply.");
    const page = structuredClone(document as ListReply);
    if (this.#complete) fail("contract_violation", "A page followed the terminal discovery page.");
    if (this.#pageCount === 0 && this.#expectedActor !== undefined && page.actor !== this.#expectedActor)
      fail("contract_violation", "Discovery first page differs from the requested actor.");
    if (this.#pageCount > 0 &&
        (page.actor !== this.#actor || !exactProfile(page.profile, this.#profile!) || page.snapshot !== this.#snapshot ||
         page.resolved_view !== this.#resolvedView))
      fail("contract_violation", "Discovery page changed actor, profile, snapshot, or view.");
    for (const summary of page.summaries) ensureProfile(summary.capability, this.#profile ?? page.profile);
    this.#validateLimits(page, encodedBytes);

    let previous = this.#lastCommand;
    const additions: Array<[string, CapabilitySummary]> = [];
    const pageCapabilities = new Set<string>();
    for (const summary of page.summaries) {
      const key = capabilityKey(summary.capability);
      if (this.#capabilities.has(key) || pageCapabilities.has(key))
        fail("contract_violation", "Duplicate capability identity in discovery pages.");
      if (previous !== undefined && compareUtf8(summary.capability.command, previous) <= 0)
        fail("contract_violation", "Capability summaries are not in UTF-8 byte order.");
      previous = summary.capability.command;
      pageCapabilities.add(key);
      additions.push([key, summary]);
    }
    if (this.#pages.has(page.page)) fail("contract_violation", "Discovery page identity repeated.");
    if (page.continuation !== undefined && this.#continuations.has(page.continuation))
      fail("contract_violation", "Discovery continuation loop detected.");

    // Callbacks run only after the complete page passes validation.
    this.#options.onPage?.(structuredClone(page));
    for (const [, summary] of additions) this.#options.onSummary?.(structuredClone(summary));

    this.#actor ??= page.actor;
    this.#profile ??= structuredClone(page.profile);
    this.#snapshot ??= page.snapshot;
    this.#resolvedView ??= page.resolved_view;
    this.#pageCount++;
    this.#itemCount += additions.length;
    this.#receivedControlBytes += encodedBytes;
    this.#complete = page.complete;
    this.#continuation = page.continuation;
    this.#lastCommand = previous;
    this.#pages.add(page.page);
    if (page.continuation !== undefined) this.#continuations.add(page.continuation);
    for (const [key, summary] of additions) {
      this.#capabilities.add(key);
      this.#collected?.push(summary);
    }
    if (page.complete) {
      this.#pages.clear();
      this.#continuations.clear();
    }
    return structuredClone(page);
  }

  summaries(): readonly CapabilitySummary[] {
    if (!this.#collected) fail("invalid_request", "Summary accumulation was not enabled.");
    if (!this.#complete) fail("contract_violation", "Capability enumeration is incomplete.");
    return structuredClone(this.#collected!);
  }

  #validateLimits(page: ListReply, encodedBytes: number): void {
    const limits = this.#limits;
    if (limits && page.summaries.length > limits.page_items)
      fail("contract_violation", "Discovery page exceeds the selected item limit.");
    if (limits && exceedsTotal(this.#itemCount, page.summaries.length, limits.view_items))
      fail("contract_violation", "Discovery view exceeds the selected item limit.");
    if (limits && encodedBytes > limits.control_bytes)
      fail("contract_violation", "Discovery page exceeds the selected byte limit.");
    if (limits) {
      for (const summary of page.summaries)
        for (const value of [summary.label, summary.description])
          if (value !== undefined && bytes(value) > limits.presentation_bytes)
            fail("contract_violation", "Discovery presentation value exceeds its byte limit.");
      for (const value of [page.actor, page.snapshot, page.resolved_view, page.page, page.continuation])
        if (value !== undefined && bytes(value) > limits.opaque_bytes)
          fail("contract_violation", "Discovery opaque value exceeds its byte limit.");
    }
    if (this.#options.maxPages !== undefined && exceedsTotal(this.#pageCount, 1, this.#options.maxPages))
      fail("request_limit", "Discovery exceeds the local page limit.");
    if (this.#options.maxItems !== undefined && exceedsTotal(this.#itemCount, page.summaries.length, this.#options.maxItems))
      fail("request_limit", "Discovery exceeds the local item limit.");
    if (this.#options.maxControlBytes !== undefined &&
        exceedsTotal(this.#receivedControlBytes, encodedBytes, this.#options.maxControlBytes))
      fail("request_limit", "Discovery exceeds the local control-byte limit.");
  }
}

const compareUtf8 = (left: string, right: string): number => Buffer.compare(utf8(left), utf8(right));

export type DiscoveryCarrier = (request: ListStartRequest | ListContinuationRequest) => Promise<unknown>;

/** Iterate validated pages from an injected, binding-neutral control carrier. */
export async function* discoverCapabilityPages(
  firstRequest: ListStartRequest,
  carrier: DiscoveryCarrier,
  options: EnumerationOptions = {}
): AsyncGenerator<ListReply, DiscoveryEnumeration> {
  const document = validateDiscovery(firstRequest);
  if (document.operation !== "capabilities.list" || document.kind !== "request" || !("start" in document))
    fail("invalid_request", "Enumeration must start with a capabilities.list start request.");
  const request = document as ListStartRequest;
  const limits = stricterLimits(request.limits, options.limits)!;
  const maxPages = localBound(options.maxPages, safeSum(limits.view_items, 1), "maxPages");
  const maxItems = localBound(options.maxItems, limits.view_items, "maxItems");
  const maxControlBytes = localBound(
    options.maxControlBytes,
    safeProduct(maxPages, limits.control_bytes),
    "maxControlBytes"
  );
  const state = new DiscoveryEnumeration({
    ...options,
    expectedActor: request.actor,
    limits,
    maxPages,
    maxItems,
    maxControlBytes
  });
  let next: ListStartRequest | ListContinuationRequest = request;
  while (true) {
    const page = state.push(await carrier(next));
    yield page;
    if (state.complete) return state;
    next = discoveryDocument("capabilities.list", "request", { continuation: state.continuation });
  }
}

/** Read all pages while retaining only identity state unless accumulation is selected. */
export async function enumerateCapabilities(
  firstRequest: ListStartRequest,
  carrier: DiscoveryCarrier,
  options: EnumerationOptions = {}
): Promise<DiscoveryEnumeration> {
  const pages = discoverCapabilityPages(firstRequest, carrier, options);
  while (true) {
    const result = await pages.next();
    if (result.done) return result.value;
  }
}

export interface ManifestOptions {
  limits?: DiscoveryLimits;
  supportedVocabularies?: Iterable<string>;
  maxSchemaNodes?: number;
}

/** Validate an atomic detail reply against a complete enumeration. */
export function validateDiscoveryDetails(
  requestInput: unknown,
  replyInput: unknown,
  enumeration: DiscoveryEnumeration,
  options: ManifestOptions = {}
): CapabilityDetail[] {
  const limits = stricterLimits(enumeration.limits, options.limits);
  if (limits) {
    enforceControlBytes(requestInput, limits.control_bytes, "request_limit", "Discovery detail request");
    enforceControlBytes(replyInput, limits.control_bytes, "contract_violation", "Discovery detail reply");
  }
  const requestDocument = validateDiscovery(requestInput);
  const replyDocument = validateDiscovery(replyInput);
  if (requestDocument.operation !== "capabilities.get" || requestDocument.kind !== "request" ||
      replyDocument.operation !== "capabilities.get" || replyDocument.kind !== "reply")
    fail("invalid_request", "Expected a capabilities.get request and reply.");
  const request = requestDocument as GetRequest;
  const reply = replyDocument as GetReply;
  const profile = enumeration.profile;
  if (!enumeration.complete) fail("contract_violation", "Capability enumeration is incomplete.");
  if (!profile) fail("contract_violation", "Capability enumeration has no actor profile.");
  const actorProfile = profile as ActorProfileDescriptor;
  if (request.snapshot !== enumeration.snapshot || reply.snapshot !== enumeration.snapshot ||
      reply.resolved_view !== enumeration.resolvedView || !exactProfile(reply.profile, actorProfile))
    fail("contract_violation", "Detail reply changed the discovery context.");
  if (limits && request.capabilities.length > limits.detail_items)
    fail("request_limit", "Detail request exceeds the selected item limit.");
  if (limits) {
    enforceOpaqueBytes([request.snapshot], limits.opaque_bytes, "request_limit");
    enforceOpaqueBytes([reply.snapshot, reply.resolved_view], limits.opaque_bytes, "contract_violation");
    for (const detail of reply.details) {
      enforceOpaqueBytes(
        [
          detail.schemas.input_root,
          detail.schemas.output_root,
          ...detail.schemas.resources.map(resource => resource.resource)
        ],
        limits.opaque_bytes,
        "contract_violation"
      );
      for (const value of [detail.label, detail.description])
        if (value !== undefined && bytes(value) > limits.presentation_bytes)
          fail("contract_violation", "Detail presentation value exceeds its byte limit.");
    }
  }
  const requested = request.capabilities.map(capabilityKey);
  if (new Set(requested).size !== requested.length)
    fail("invalid_request", "Detail request contains a duplicate capability identity.");
  const returned = reply.details.map(detail => capabilityKey(detail.capability));
  if (requested.length !== returned.length || requested.some((key, index) => key !== returned[index]))
    fail("contract_violation", "Detail reply is not atomic and in request order.");

  // Validate every detail before returning any part of the reply.
  for (const detail of reply.details) {
    ensureProfile(detail.capability, actorProfile);
    if (!enumeration.hasCapability(detail.capability))
      fail("contract_violation", "Detail is outside the advertised snapshot.");
    validateSchemaManifest(detail.schemas, { ...options, limits });
  }
  return structuredClone(reply.details);
}

const standardVocabularies = new Set([
  "https://json-schema.org/draft/2020-12/vocab/core",
  "https://json-schema.org/draft/2020-12/vocab/applicator",
  "https://json-schema.org/draft/2020-12/vocab/unevaluated",
  "https://json-schema.org/draft/2020-12/vocab/validation",
  "https://json-schema.org/draft/2020-12/vocab/meta-data",
  "https://json-schema.org/draft/2020-12/vocab/format-annotation",
  "https://json-schema.org/draft/2020-12/vocab/content"
]);

/** Reject identities that could be mistaken for a network, file, or code location. */
export function safeResourceIdentity(identity: unknown): identity is string {
  return typeof identity === "string" && bytes(identity) > 0 && bytes(identity) <= 4096 &&
    !identity.includes("\0") && !identity.includes("\\") && !identity.includes("../") &&
    !identity.includes("..\\") && !identity.startsWith("/") && !identity.startsWith("./") &&
    !/^(?:https?|file|ftp):/i.test(identity) && !/^urn:[^\s]*:module(?::|$)/i.test(identity);
}

export interface ResourceVerification { resource: string; byteLength: number; sha256: string }

/** Incrementally verify the exact decoded representation of one resource. */
export class DiscoveryResourceVerifier {
  readonly #descriptor: ResourceDescriptor;
  readonly #hash: Hash = createHash("sha256");
  #byteLength = 0;
  #finished = false;

  constructor(descriptorInput: unknown) {
    if (isRecord(descriptorInput) && isRecord(descriptorInput.digest) &&
        descriptorInput.digest.algorithm !== "sha-256")
      fail("unsupported_digest", "Only sha-256 discovery resource digests are supported.");
    const validate = validators().resource;
    if (!validate(descriptorInput))
      fail("invalid_request", "Invalid discovery resource descriptor.", validate.errors);
    this.#descriptor = structuredClone(descriptorInput as ResourceDescriptor);
    if (!safeResourceIdentity(this.#descriptor.resource))
      fail("unsafe_identity", "Resource identity is unsafe for local or remote resolution.");
  }

  get descriptor(): ResourceDescriptor { return structuredClone(this.#descriptor); }

  update(chunk: Uint8Array): this {
    if (this.#finished) fail("invalid_request", "Schema resource verifier is already complete.");
    if (!(chunk instanceof Uint8Array)) fail("invalid_request", "A schema resource chunk must be bytes.");
    this.#byteLength += chunk.byteLength;
    if (this.#byteLength > this.#descriptor.byte_length)
      fail("length_mismatch", "Schema resource is longer than its declared byte length.");
    this.#hash.update(chunk);
    return this;
  }

  finish(): ResourceVerification {
    if (this.#finished) fail("invalid_request", "Schema resource verifier is already complete.");
    this.#finished = true;
    if (this.#byteLength !== this.#descriptor.byte_length)
      fail("length_mismatch", "Schema resource byte length does not match its descriptor.");
    const digest = this.#hash.digest("hex");
    if (this.#descriptor.digest && digest !== this.#descriptor.digest.value)
      fail("digest_mismatch", "Schema resource SHA-256 digest does not match.");
    return { resource: this.#descriptor.resource, byteLength: this.#byteLength, sha256: digest };
  }
}

export function verifyDiscoveryResource(descriptor: ResourceDescriptor, chunks: Iterable<Uint8Array>): ResourceVerification {
  const verifier = new DiscoveryResourceVerifier(descriptor);
  for (const chunk of chunks) verifier.update(chunk);
  return verifier.finish();
}

interface SchemaObject { [key: string]: SchemaValue }
const schemaNumber = Symbol("schema-number");
type SchemaValue = null | boolean | string | typeof schemaNumber | SchemaValue[] | SchemaObject;
const DEFAULT_MAX_SCHEMA_NODES = 100_000;

/** Parse schema JSON without evaluating keywords and with duplicate-key detection. */
function parseSchemaJSON(
  input: Uint8Array,
  maxNodes: number
): { value: boolean | SchemaObject; nodeCount: number } {
  let source: string;
  try { source = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(input); }
  catch { return fail("invalid_schema", "Schema resource is not UTF-8 JSON."); }
  let position = 0;
  let nodeCount = 0;
  const numberPattern = /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/y;
  const whitespace = (): void => { while (/[ \t\r\n]/.test(source[position] ?? "")) position++; };
  const parseString = (): string => {
    const start = position++;
    while (position < source.length) {
      const character = source[position++];
      if (character === "\\") { position++; continue; }
      if (character === '"') {
        try { return JSON.parse(source.slice(start, position)) as string; }
        catch { return fail("invalid_schema", "Schema resource has an invalid JSON string."); }
      }
    }
    return fail("invalid_schema", "Schema resource has an unclosed JSON string.");
  };
  const parseValue = (depth: number): SchemaValue => {
    if (depth > 128) return fail("invalid_schema", "Schema resource nesting exceeds the client limit.");
    if (++nodeCount > maxNodes) return fail("request_limit", "Schema resource exceeds the local node limit.");
    whitespace();
    const character = source[position];
    if (character === '"') return parseString();
    if (character === "{" || character === "[") {
      const object = character === "{", end = object ? "}" : "]";
      position++; whitespace();
      const result: SchemaValue[] | SchemaObject = object ? Object.create(null) as SchemaObject : [];
      if (source[position] === end) { position++; return result; }
      while (true) {
        whitespace();
        if (object) {
          if (source[position] !== '"') return fail("invalid_schema", "Schema object key must be a string.");
          const key = parseString();
          if (Object.hasOwn(result, key)) return fail("duplicate_json_key", "Schema resource contains a duplicate JSON object key.");
          whitespace();
          if (source[position++] !== ":") return fail("invalid_schema", "Schema resource has a missing colon.");
          (result as SchemaObject)[key] = parseValue(depth + 1);
        } else (result as SchemaValue[]).push(parseValue(depth + 1));
        whitespace();
        if (source[position] === end) { position++; return result; }
        if (source[position++] !== ",") return fail("invalid_schema", "Schema resource has a missing comma.");
      }
    }
    for (const [token, value] of [["true", true], ["false", false], ["null", null]] as const)
      if (source.startsWith(token, position)) { position += token.length; return value; }
    numberPattern.lastIndex = position;
    const token = numberPattern.exec(source)?.[0];
    if (!token) return fail("invalid_schema", "Schema resource has an invalid JSON value.");
    position += token.length;
    return schemaNumber;
  };
  const value = parseValue(0);
  whitespace();
  if (position !== source.length) fail("invalid_schema", "Schema resource has trailing JSON data.");
  if (typeof value !== "boolean" && !isRecord(value))
    fail("invalid_schema", "A JSON Schema root must be an object or boolean.");
  return { value: value as boolean | SchemaObject, nodeCount };
}

export interface SchemaClosure {
  input: Uint8Array;
  output: Uint8Array;
  resources: ReadonlyMap<string, Uint8Array>;
}

/** A closed manifest that accepts only injected exact resource bytes. */
export class DiscoverySchemaManifest {
  readonly #document: SchemaManifestDocument;
  readonly #descriptors: Map<string, ResourceDescriptor>;
  readonly #supportedVocabularies: Set<string>;
  readonly #values = new Map<string, boolean | SchemaObject>();
  readonly #resources = new Map<string, Uint8Array>();
  readonly #maxSchemaNodes: number;
  #schemaNodeCount = 0;

  constructor(documentInput: unknown, options: ManifestOptions = {}) {
    const validate = validators().manifest;
    if (!validate(documentInput))
      fail("invalid_request", "Invalid discovery schema manifest.", validate.errors);
    this.#document = structuredClone(documentInput as SchemaManifestDocument);
    const supported = new Set(standardVocabularies);
    for (const vocabulary of options.supportedVocabularies ?? []) supported.add(vocabulary);
    this.#supportedVocabularies = supported;
    this.#maxSchemaNodes = positiveSafeInteger(
      options.maxSchemaNodes ?? DEFAULT_MAX_SCHEMA_NODES,
      "maxSchemaNodes"
    );

    const resourceIds = this.#document.resources.map(resource => resource.resource);
    ensureUnique(resourceIds, "resource identity", "invalid_request");
    ensureUnique(this.#document.resources.flatMap(resource => resource.schema_id ? [resource.schema_id] : []), "schema identity", "invalid_request");
    for (const resource of this.#document.resources) {
      if (!safeResourceIdentity(resource.resource)) fail("unsafe_identity", "Manifest contains an unsafe resource identity.");
      if (resource.dialect !== JSON_SCHEMA_2020_12) fail("unsupported_contract", "Only JSON Schema 2020-12 resources are supported.");
    }
    if (!resourceIds.includes(this.#document.input_root) || !resourceIds.includes(this.#document.output_root))
      fail("unresolved_reference", "A schema root is outside the closed manifest.");
    ensureUnique(this.#document.vocabularies.map(vocabulary => vocabulary.uri), "vocabulary identity", "invalid_request");
    ensureVocabularies(this.#document.vocabularies, supported);
    const limits = options.limits;
    if (limits && this.#document.resources.length > limits.closure_resources)
      fail("request_limit", "Schema closure exceeds the selected resource limit.");
    const declaredBytes = this.#document.resources.reduce((sum, resource) => sum + resource.byte_length, 0);
    if (limits && declaredBytes > limits.closure_bytes)
      fail("request_limit", "Schema closure exceeds the selected byte limit.");
    if (limits && this.#document.resources.some(resource => resource.byte_length > limits.resource_bytes))
      fail("request_limit", "Schema resource exceeds the selected byte limit.");
    this.#descriptors = new Map(this.#document.resources.map(resource => [resource.resource, structuredClone(resource)]));
  }

  get document(): SchemaManifestDocument { return structuredClone(this.#document); }
  get descriptors(): ReadonlyMap<string, ResourceDescriptor> {
    return new Map([...this.#descriptors].map(([identity, descriptor]) => [identity, structuredClone(descriptor)]));
  }
  get supportedVocabularies(): ReadonlySet<string> { return new Set(this.#supportedVocabularies); }

  putResource(identity: string, input: string | Uint8Array): this {
    const descriptor = this.#descriptors.get(identity);
    if (!descriptor) return fail("unresolved_reference", "Resource is not in the closed manifest.");
    if (this.#resources.has(identity)) fail("duplicate_resource", "Schema resource was supplied more than once.");
    const representation = asBytes(input);
    const verifier = new DiscoveryResourceVerifier(descriptor);
    verifier.update(representation).finish();
    const parsed = parseSchemaJSON(representation, this.#maxSchemaNodes - this.#schemaNodeCount);
    const value = parsed.value;
    if (typeof value !== "boolean") {
      if (descriptor.schema_id !== undefined && typeof value.$id === "string" && descriptor.schema_id !== value.$id)
        fail("contract_violation", "Resource root $id differs from its descriptor schema_id.");
      if (typeof value.$schema === "string" && descriptor.dialect !== value.$schema)
        fail("contract_violation", "Resource root $schema differs from its descriptor dialect.");
    }
    this.#resources.set(identity, representation.slice());
    this.#values.set(identity, value);
    this.#schemaNodeCount += parsed.nodeCount;
    return this;
  }

  finish(): SchemaClosure {
    if (this.#resources.size !== this.#descriptors.size)
      fail("unresolved_reference", "The schema resource closure is incomplete.");
    validateSchemaClosure(this.#values, this.#descriptors, this.#supportedVocabularies);
    return {
      input: this.#resources.get(this.#document.input_root)!.slice(),
      output: this.#resources.get(this.#document.output_root)!.slice(),
      resources: new Map([...this.#resources].map(([identity, value]) => [identity, value.slice()]))
    };
  }
}

export function validateSchemaManifest(document: unknown, options: ManifestOptions = {}): DiscoverySchemaManifest {
  return new DiscoverySchemaManifest(document, options);
}

export type DiscoveryResourceSource = string | Uint8Array | Iterable<Uint8Array> | AsyncIterable<Uint8Array>;
export type DiscoveryResourceCarrier = (descriptor: ResourceDescriptor) => DiscoveryResourceSource | Promise<DiscoveryResourceSource>;

/** Read one closure through an injected transport without interpreting resource identities as locations. */
export async function readDiscoverySchemaClosure(
  manifest: DiscoverySchemaManifest,
  carrier: DiscoveryResourceCarrier
): Promise<SchemaClosure> {
  for (const descriptor of manifest.descriptors.values()) {
    const source = await carrier(descriptor);
    if (typeof source === "string" || source instanceof Uint8Array) {
      manifest.putResource(descriptor.resource, source);
      continue;
    }
    const verifier = new DiscoveryResourceVerifier(descriptor);
    const chunks: Uint8Array[] = [];
    for await (const chunk of source) {
      if (!(chunk instanceof Uint8Array)) fail("invalid_schema", "A resource carrier returned a non-byte chunk.");
      verifier.update(chunk);
      chunks.push(chunk.slice());
    }
    verifier.finish();
    const complete = new Uint8Array(chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0));
    let offset = 0;
    for (const chunk of chunks) { complete.set(chunk, offset); offset += chunk.byteLength; }
    // putResource repeats exact verification, then performs JSON and closure checks.
    manifest.putResource(descriptor.resource, complete);
  }
  return manifest.finish();
}

const ensureUnique = (values: readonly string[], name: string, code: string): void => {
  if (new Set(values).size !== values.length) fail(code, `Manifest contains a duplicate ${name}.`);
};
const ensureVocabularies = (
  vocabularies: ReadonlyArray<{ uri: string; required: boolean }>,
  supported: ReadonlySet<string>
): void => {
  for (const vocabulary of vocabularies)
    if (vocabulary.required && !supported.has(vocabulary.uri))
      fail("unsupported_vocabulary", "Schema closure requires an unsupported vocabulary.");
};
const absoluteUri = (value: string): boolean => /^[A-Za-z][A-Za-z0-9+.-]*:[^\s]*$/.test(value);
const resolveUri = (base: string, value: string, kind: "id" | "reference"): string => {
  if (absoluteUri(value)) return value;
  if (value.startsWith("#")) return base + value;
  if (base.startsWith("urn:dasp:private-resource:"))
    fail("unresolved_reference", "Relative schema reference has no public base URI.");
  try {
    const resolved = new URL(value, base).toString();
    if (!absoluteUri(resolved)) throw new Error("not absolute");
    return resolved;
  } catch {
    return fail(kind === "id" ? "invalid_schema" : "unresolved_reference", "Relative schema URI cannot be resolved against its base.");
  }
};
const privateBase = (resource: string): string =>
  `urn:dasp:private-resource:${Buffer.from(utf8(resource)).toString("hex")}`;

interface ClosureState {
  nodes: Map<string, SchemaValue>;
  anchors: Set<string>;
  references: Array<{ reference: string; base: string }>;
  vocabularies: Array<{ uri: string; required: boolean }>;
}

const singleSchemaKeywords = [
  "additionalProperties", "contains", "contentSchema", "else", "if", "items", "not",
  "propertyNames", "then", "unevaluatedItems", "unevaluatedProperties"
] as const;
const schemaArrayKeywords = ["allOf", "anyOf", "oneOf", "prefixItems"] as const;
const schemaMapKeywords = ["$defs", "dependentSchemas", "patternProperties", "properties"] as const;

function validateSchemaClosure(
  resources: ReadonlyMap<string, boolean | SchemaObject>,
  descriptors: ReadonlyMap<string, ResourceDescriptor>,
  supported: ReadonlySet<string>
): void {
  const state: ClosureState = { nodes: new Map(), anchors: new Set(), references: [], vocabularies: [] };
  for (const [resource, value] of resources) {
    const base = descriptors.get(resource)!.schema_id ?? privateBase(resource);
    if (typeof value === "boolean") putNode(base, value, state);
    else walkSchema(value, base, true, state);
  }
  ensureVocabularies(state.vocabularies, supported);
  for (const item of state.references) resolveReference(item, state);
}

function walkSchema(value: SchemaValue, base: string, root: boolean, state: ClosureState): void {
  if (!isRecord(value)) return;
  let currentBase = base;
  const id = value.$id;
  if (id !== undefined) {
    if (typeof id !== "string") fail("invalid_schema", "Schema $id must be a string.");
    currentBase = resolveUri(base, id as string, "id");
    if (currentBase.includes("#")) fail("invalid_schema", "Schema $id must be an absolute URI without a fragment.");
    putNode(currentBase, value, state);
  } else if (root) putNode(currentBase, value, state);

  for (const name of ["$anchor", "$dynamicAnchor"] as const) {
    const anchor = value[name];
    if (anchor === undefined) continue;
    if (typeof anchor !== "string" || !/^[A-Za-z_][-A-Za-z0-9._]*$/.test(anchor))
      fail("invalid_schema", "Schema anchor has invalid syntax.");
    const key = `${currentBase}#${anchor as string}`;
    if (state.anchors.has(key)) fail("duplicate_schema_anchor", "Schema closure contains a duplicate anchor.");
    state.anchors.add(key);
  }
  const vocabularies = value.$vocabulary;
  if (vocabularies !== undefined) {
    if (!isRecord(vocabularies))
      fail("invalid_schema", "Schema $vocabulary must be an object.");
    for (const [uri, required] of Object.entries(vocabularies as SchemaObject)) {
      if (!absoluteUri(uri) || typeof required !== "boolean")
        fail("invalid_schema", "Schema has an invalid $vocabulary declaration.");
      state.vocabularies.push({ uri, required: required as boolean });
    }
  }
  for (const name of ["$ref", "$dynamicRef"] as const) {
    const reference = value[name];
    if (reference === undefined) continue;
    if (typeof reference !== "string") fail("invalid_schema", "Schema reference must be a string.");
    state.references.push({ reference: reference as string, base: currentBase });
  }
  for (const keyword of singleSchemaKeywords)
    if (Object.hasOwn(value, keyword)) walkSchema(value[keyword]!, currentBase, false, state);
  for (const keyword of schemaArrayKeywords) {
    const schemas = value[keyword];
    if (Array.isArray(schemas))
      for (const schema of schemas) walkSchema(schema, currentBase, false, state);
  }
  for (const keyword of schemaMapKeywords) {
    const schemas = value[keyword];
    if (isRecord(schemas))
      for (const schema of Object.values(schemas)) walkSchema(schema, currentBase, false, state);
  }
}

function putNode(identity: string, value: SchemaValue, state: ClosureState): void {
  if (state.nodes.has(identity))
    fail("duplicate_schema_identity", "Schema closure contains a duplicate $id.");
  state.nodes.set(identity, value);
}

function resolveReference(item: { reference: string; base: string }, state: ClosureState): void {
  const resolved = item.reference.startsWith("#") ? item.base + item.reference : resolveUri(item.base, item.reference, "reference");
  const marker = resolved.indexOf("#");
  const base = marker < 0 ? resolved : resolved.slice(0, marker);
  const fragment = marker < 0 ? undefined : resolved.slice(marker + 1);
  const target = state.nodes.get(base);
  if (target === undefined) return fail("unresolved_reference", "Schema reference is outside the closed manifest.");
  if (fragment === undefined || fragment === "") return;
  let decoded: string;
  try { decoded = decodeURIComponent(fragment); }
  catch { return fail("unresolved_reference", "Schema reference fragment is invalid."); }
  if (decoded.startsWith("/")) {
    if (!jsonPointer(target, decoded)) fail("unresolved_reference", "Schema JSON Pointer does not resolve.");
  } else if (!state.anchors.has(`${base}#${decoded}`))
    fail("unresolved_reference", "Schema anchor does not resolve.");
}

function jsonPointer(value: SchemaValue, pointer: string): boolean {
  let current: SchemaValue = value;
  for (const raw of pointer.slice(1).split("/")) {
    const token = raw.replace(/~1/g, "/").replace(/~0/g, "~");
    if (Array.isArray(current)) {
      if (!/^(?:0|[1-9]\d*)$/.test(token) || Number(token) >= current.length) return false;
      current = current[Number(token)]!;
    } else if (isRecord(current) && Object.hasOwn(current, token)) {
      current = current[token]! as SchemaValue;
    } else return false;
  }
  return true;
}
