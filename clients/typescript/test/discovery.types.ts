import {
  DISCOVERY_CONTRACT,
  DISCOVERY_VERSION,
  type ActorProfileDescriptor,
  type CapabilitySummary,
  type DiscoveryFailure,
  type ListReply
} from "../src/discovery.js";

const profile: ActorProfileDescriptor = {
  uri: "urn:example:profile",
  version: "1",
  content_ref: "urn:example:profile-content",
  core: {
    id: "https://dasp-protocol.github.io/dasp/contracts/core",
    version: "draft-01",
    content_ref: "urn:example:core-content"
  }
};
const summary: CapabilitySummary = {
  capability: {
    profile_uri: profile.uri,
    profile_version: profile.version,
    command: "example.run"
  },
  profile_requirement: "required"
};
const replyBase = {
  contract: DISCOVERY_CONTRACT,
  version: DISCOVERY_VERSION,
  operation: "capabilities.list",
  kind: "reply",
  actor: "actor:one",
  profile,
  snapshot: "snapshot:one",
  resolved_view: "view:one",
  page: "page:one"
} as const;

const terminal: ListReply = { ...replyBase, summaries: [], complete: true };
const nonterminal: ListReply = {
  ...replyBase,
  summaries: [summary],
  complete: false,
  continuation: "continuation:two"
};

// @ts-expect-error Terminal replies cannot contain continuation tokens.
const terminalWithContinuation: ListReply = {
  ...replyBase,
  summaries: [],
  complete: true,
  continuation: "continuation:invalid"
};
// @ts-expect-error Nonterminal replies must contain at least one summary.
const emptyNonterminal: ListReply = {
  ...replyBase,
  summaries: [],
  complete: false,
  continuation: "continuation:invalid"
};

const limitFailure: DiscoveryFailure = {
  contract: DISCOVERY_CONTRACT,
  version: DISCOVERY_VERSION,
  operation: "capabilities.list",
  kind: "failure",
  code: "snapshot_capacity",
  limit: { name: "live_snapshots", maximum: 2 }
};
const unavailable: DiscoveryFailure = {
  contract: DISCOVERY_CONTRACT,
  version: DISCOVERY_VERSION,
  operation: "capabilities.list",
  kind: "failure",
  code: "unavailable"
};
const invalidFailureLimit: DiscoveryFailure = {
  contract: DISCOVERY_CONTRACT,
  version: DISCOVERY_VERSION,
  operation: "capabilities.list",
  kind: "failure",
  code: "invalid_request",
  // @ts-expect-error Non-limit failure codes cannot contain limit detail.
  limit: { name: "page_items", maximum: 1 }
};

void [terminal, nonterminal, terminalWithContinuation, emptyNonterminal, limitFailure, unavailable, invalidFailureLimit];
