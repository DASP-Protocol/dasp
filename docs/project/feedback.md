# Review the draft

The current review scope is the draft-01 core, its message shapes, and the evidence needed to implement it. Report a concrete ambiguity, contradiction, missing failure case, or integration constraint.

[Open a specification issue](https://github.com/DASP-Protocol/dasp/issues/new?template=specification.yml).

## Open decisions

| Topic | Current position | Review question |
| --- | --- | --- |
| First transport binding | None selected | Which transport lets you test an existing actor with the least adaptation? |
| First application profile | Counter is illustrative | Which useful agent or workflow contract should be specified first? |
| Retention | All records remain for the session lifetime | What bounded retention and recovery rules will implementations need? |
| Data values | Safe integers; exact fractions use profile strings | Does this restriction fit the intended applications? |
| Command identity | Unique across sessions in one host authority | Is this scope practical for independent clients? |
| Uncertainty | Terminal and immutable | Can a separate reconciliation command preserve the original evidence? |
| Multiple clients | Shared history and independent cursors | Which additional conflict rules belong in application profiles? |

No presence, shared editing, transport, or cancellation proposal is a core feature merely because an application needs it.

## Report enough detail

Include the draft and source commit, requirement ID or message, a small example, the observed ambiguity, and expected behavior. State whether the issue affects a client, host, profile, or binding.

The [coverage index](../../conformance/README.md) separates implemented checks from planned runtime cases. Tests can also contain defects; report a test expectation that conflicts with a requirement.
