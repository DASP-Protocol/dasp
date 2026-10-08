# Status and open decisions

Draft-01 defines the core, progressive capability discovery, extension selection rules, the first WebSocket delivery rules, and optional encryption and proof-of-authority rules. The schemas, recorded examples, and experimental clients can be checked locally. The [capability overview](../specification/capabilities.md) shows how these parts fit and where evidence is still required. No production host or binding is released.

The next step is to complete authenticated binding setup, implement a persistent example host, and test it with both clients. That will put the recovery rules under real failure conditions.

Report an ambiguity, missing failure case, or integration constraint.

[Open a specification issue](https://github.com/DASP-Protocol/dasp/issues/new?template=specification.yml).

## Open decisions

| Topic | Current position | Open work or question |
| --- | --- | --- |
| First transport binding | WebSocket live delivery rules are selected | Complete exact setup, shared limits, health controls, and runtime tests. |
| Capability discovery | Abstract setup contract with bounded pages, selective details, and exact resources | Define the first binding mapping and test authenticated framing, correlation, resource streaming, close behavior, and independent interoperability. |
| Extension selection | Exact identity, version, content, scope, dependencies, and saved protection floor | Define setup bytes and test required-feature refusal, reconnect enforcement, and upgrade behavior. |
| Payload encryption | Optional contract; executing host can read payloads | Complete setup, independent cryptographic tests, and security review. |
| Proof of authority | Optional reusable standing grants and exact-command grants | Test host scope enforcement, atomic budgets, recovery, and revocation. |
| First application profile | Counter is illustrative | Which useful agent or workflow contract should be specified first? |
| Retention | All records remain for the session lifetime | What bounded retention and recovery rules will implementations need? |
| Data values | Safe integers; exact fractions use profile strings | Does this restriction fit the intended applications? |
| Command identity | Unique across sessions in one host authority | Is this scope practical for independent clients? |
| Uncertainty | Terminal and immutable | Can a separate reconciliation command preserve the original evidence? |
| Multiple clients | Shared history and independent cursors | Which additional conflict rules belong in application profiles? |
| Connection management note | Public non-normative design note, excluded from the generated specification | Keep it as implementation guidance, move it into a binding draft, or remove it from the public repository? |

No presence, shared editing, transport, or cancellation proposal is a core feature merely because an application needs it.

## Report enough detail

Include the draft and source commit, requirement ID or message, a small example, the observed ambiguity, and expected behavior. State whether the issue affects a client, host, profile, or binding.

The [coverage index](../../conformance/README.md) separates implemented checks from planned runtime cases. Tests can also contain defects; report a test expectation that conflicts with a requirement.
