# Glossary

Use these terms when reading messages and recovery rules.

| Term | Meaning |
| --- | --- |
| CloudEvents | Open standard for the event envelope; [why DASP uses it](../guide/cloudevents.md) |
| Actor | Logical target that performs application work |
| Host authority | Service that owns sessions, command retry records, and saved updates |
| Setup subprotocol | Versioned behavior that runs through an authenticated binding mapping before normal profile confirmation and core operation |
| Capability discovery | Optional setup subprotocol that reveals one actor profile and a complete advertised capability view |
| Profile capability universe | All command capabilities that one exact profile defines, marked required or optional |
| Actor effective capability set | All required profile capabilities plus optional capabilities that one actor activates |
| Advertised view | Disclosure projection of one actor's effective capabilities for one authenticated context |
| Capability identity | Exact profile URI, exact profile version, and command name |
| Discovery snapshot | Immutable, read-only, connection-scoped boundary for one advertised view |
| Continuation token | Opaque, non-authorizing reference to the next page in one discovery snapshot |
| Resolved-view identity | Opaque, non-authorizing identity for the advertised view that a host resolved |
| Session | Fixed actor/profile binding with one ordered history |
| Command | Application intent with a durable command ID |
| Admission | Recoverable decision to accept a command |
| Receipt | Accepted, duplicate, or rejected admission result |
| Outcome | Saved result: completed, failed, cancelled, or uncertain |
| Update | Immutable saved session fact with a sequence |
| Cursor | Last update applied to a client's saved state |
| View | Coherent state projection at a cursor |
| Progress | Temporary information that does not settle a command |
| Profile | Versioned application commands, payloads, state, and completion rules |
| Profile thread or episode | Profile-owned application grouping for commands in one session; it has no independent core cursor or recovery |
| Binding | Versioned transport, selection, routing, and delivery rules |

See [capability discovery](../specification/capability-discovery.md),
[model](../specification/model.md),
[messages](../specification/messages.md), and
[profiles and bindings](../specification/profiles-and-bindings.md).
