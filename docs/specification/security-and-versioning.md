# Security and version rules

The source uses trusted caller context for authorization. A Signal source, Session ID, or channel topic does not grant access. The current local profile tests token binding and principal isolation. External authentication and exact deployment policy remain release decisions.

Protocol version `1`, profile `coding`, package version `0.1.0-dev`, and a contract digest are separate identities. The frozen bundle fixes one baseline. Later opt-in initialization preserves the legacy join and selects a versioned profile, features, and limits.

Closed schemas reject unknown fields. Adding a field is not automatically compatible. Preserve saved Session identity, command retry records, Results, and Update meaning. An unreadable saved event must fail explicitly before cursor advancement.

Full rules: [wire](../../upstream/seigyo/docs/seigyo/wire.md), [release policy](../../upstream/seigyo/docs/seigyo/release-policy.md), and [initialization decision](../../upstream/seigyo/docs/seigyo/initialization-decision.md).
