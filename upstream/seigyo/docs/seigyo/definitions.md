# Seigyo Protocol canonical definitions

| ID | Requirement |
| --- | --- |
| SEIGYO-DEFINITION-001 | Each operation MUST have one catalog record for its request and reply shapes, direction, profile, retry category, allowed failure codes, failure delivery, argument order, and requirement references. Generated descriptors and simple adapter dispatch mappings MUST use this record. Handlers and live authorization MUST remain server code. |
| SEIGYO-DEFINITION-002 | The catalog MUST distinguish Requests, Replies, and Events. Saved Updates, transient Progress, and delivery control have different authority. Runtime routes and diagnostics MUST NOT become callable protocol operations. |
| SEIGYO-DEFINITION-003 | Each wire field constraint MUST have one protocol definition. Client projection types MUST reuse it and validate the complete canonical payload before projection. Projection MUST NOT discard an unknown field or turn an invalid absent value into a valid null. Typed client values may flatten or combine validated wire values. |
| SEIGYO-DEFINITION-004 | Validation and artifact generation MUST work without starting a connection or the server. An internal consolidation MUST preserve the frozen v1 schemas and the wire behavior. Independent boundary vectors MUST remain separate from generated inventories. |

The catalog contains data and links to requirements. It is not a runtime policy
engine. Failure codes describe the closed failure vocabulary, not a promise
that every code is possible at every operation. Exact error precedence remains
in the wire and lifecycle requirements and independent error matrix.
