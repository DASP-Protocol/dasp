# Glossary

Use these terms when reading messages and recovery rules.

| Term | Meaning |
| --- | --- |
| CloudEvents | Open standard for the event envelope; [why DASP uses it](../guide/cloudevents.md) |
| Actor | Logical target that performs application work |
| Host authority | Service that owns sessions, command retry records, and saved updates |
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
| Binding | Versioned transport, selection, routing, and delivery rules |

See [model](../specification/model.md), [messages](../specification/messages.md), and [profiles and bindings](../specification/profiles-and-bindings.md).
