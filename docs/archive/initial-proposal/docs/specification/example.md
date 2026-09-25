> Superseded initial proposal. This file does not define DASP or Seigyo. Use the current project documentation.

# Example exchange

This example uses an application-defined counter actor, `counter-1`. The host has already provisioned that actor. Its `increment` command adds `input.amount` to `state.value` and returns the new value. This command is an example, not a core DASP method.

The client first opens an authenticated connection and selects a version.

```json
{"jsonrpc":"2.0","id":"r1","method":"initialize","params":{"protocolVersions":["0.1.0-draft.1"]}}
```

```json
{"jsonrpc":"2.0","id":"r1","result":{"protocolVersion":"0.1.0-draft.1","limits":{"maxMessageBytes":1048576,"maxPendingRequests":64}}}
```

The client chooses a session identifier. Repeating this request with a new request identifier does not create another session.

```json
{"jsonrpc":"2.0","id":"r2","method":"session.open","params":{"sessionId":"session-1","actorId":"counter-1"}}
```

```json
{"jsonrpc":"2.0","id":"r2","result":{"snapshot":{"sessionId":"session-1","actorId":"counter-1","revision":"0","status":"open","state":{"value":0}}}}
```

The client subscribes before sending a command.

```json
{"jsonrpc":"2.0","id":"r3","method":"session.subscribe","params":{"sessionId":"session-1"}}
```

```json
{"jsonrpc":"2.0","id":"r3","result":{"subscriptionId":"sub-1","snapshot":{"sessionId":"session-1","actorId":"counter-1","revision":"0","status":"open","state":{"value":0}}}}
```

The client records the command identity and input before sending it.

```json
{"jsonrpc":"2.0","id":"r4","method":"session.command","params":{"sessionId":"session-1","commandId":"command-1","name":"increment","input":{"amount":1},"expectedRevision":"0"}}
```

The host commits the command record and state. It then sends the result and update. Their relative order is not significant.

```json
{"jsonrpc":"2.0","id":"r4","result":{"commandId":"command-1","revision":"1","output":{"value":1}}}
```

```json
{"jsonrpc":"2.0","method":"session.changed","params":{"subscriptionId":"sub-1","snapshot":{"sessionId":"session-1","actorId":"counter-1","revision":"1","status":"open","state":{"value":1}}}}
```

## Lost response

Suppose the connection fails after commit, before the client receives either message. The client opens a new connection, authenticates, initializes, and subscribes again. The new snapshot contains revision `"1"` and value `1`.

The client can query the old command on the new connection.

```json
{"jsonrpc":"2.0","id":"r5","method":"session.result","params":{"sessionId":"session-1","commandId":"command-1"}}
```

```json
{"jsonrpc":"2.0","id":"r5","result":{"status":"succeeded","result":{"commandId":"command-1","revision":"1","output":{"value":1}}}}
```

It can also retry the exact command with a new request identifier. The old `expectedRevision` remains part of that command. The duplicate lookup occurs before the revision check.

```json
{"jsonrpc":"2.0","id":"r6","method":"session.command","params":{"sessionId":"session-1","commandId":"command-1","name":"increment","input":{"amount":1},"expectedRevision":"0"}}
```

```json
{"jsonrpc":"2.0","id":"r6","result":{"commandId":"command-1","revision":"1","output":{"value":1}}}
```

The retry does not increment the counter and does not create another update.

A new command with a stale revision fails before application execution.

```json
{"jsonrpc":"2.0","id":"r7","method":"session.command","params":{"sessionId":"session-1","commandId":"command-2","name":"increment","input":{"amount":1},"expectedRevision":"0"}}
```

```json
{"jsonrpc":"2.0","id":"r7","error":{"code":-32008,"message":"Session revision does not match","data":{"kind":"REVISION_CONFLICT","currentRevision":"1"}}}
```

The host stores this rejection for `command-2`. A later attempt with revised input or a new expected revision requires a new command identifier.
