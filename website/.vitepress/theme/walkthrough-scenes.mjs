// Illustrative application vocabulary. These are examples, not a released profile.
const session = 'session-dependency';
const command = 'update-042';
const host = 'urn:example:host:one';
const web = 'urn:example:client:web';
const cli = 'urn:example:client:cli';
function event(type, id, source, data, requestid) {
  return { specversion: '1.0', id, source, type: `dasp.${type}.v1`, datacontenttype: 'application/json', ...(requestid ? { requestid } : {}), data };
}
const intent = { session_id: session, command_id: command, name: 'dependency.update', input: { repository: 'example/service', package: 'example-lib', target_version: '2.4.0' } };
const submit = event('command', 'request-event-1', web, intent, 'attempt-1');
const accepted = event('update', 'saved-1', host, { session_id: session, command_id: command, sequence: 1, kind: 'command.accepted', payload: { name: intent.name } });
const receipt = disposition => ({ session_id: session, command_id: command, disposition, admission_sequence: 1, error: null });
const checks = event('update', 'saved-2', host, { session_id: session, command_id: command, sequence: 2, kind: 'application', payload: { name: 'dependency.checks_passed', data: { repository: 'example/service' } } });
const outcome = { status: 'uncertain', output: null, error: { code: 'effect_unknown', message: 'Pull request creation could not be confirmed.', retryable: false } };
const uncertain = event('update', 'saved-3', host, { session_id: session, command_id: command, sequence: 3, kind: 'command.outcome', payload: outcome });

export const scenes = [
  {
    label: 'Send', title: 'The server saved it. Your app cannot tell yet.',
    text: 'The server saves the command before sending an accepted receipt. That reply is lost. The spinner keeps turning, although the work has been admitted.',
    clientKnows: 'No reply arrived. The client cannot infer rejection or completion.',
    serverKeeps: 'Command update-042 and its admission at update 1.',
    lesson: 'A timeout describes the connection. It does not establish what happened to the work.',
    browser: 'Reply not received', cli: 'Not connected', tool: 'Not called yet', state: 'Admitted', count: 1,
    caption: 'The reply can disappear. The saved admission remains.',
    rule: '/specification/recovery.html#dasp-core-004', ruleLabel: 'Saved admission before acceptance',
    messageNote: 'An authorized session is already open on an illustrative dependency actor. The command name and input belong to its application profile. The accepted receipt below is sent, but does not reach the client.',
    messages: [submit, accepted, event('receipt', 'reply-1', host, receipt('accepted'), 'attempt-1')]
  },
  {
    label: 'Disconnect', title: 'Close the tab. The session remains.',
    text: 'You close the browser. The actor continues and reports that its tests passed. The server saves that application fact as update 2. No client needs to stay online to keep the record.',
    clientKnows: 'Its applied cursor is still 0. It has not read any saved updates.',
    serverKeeps: 'The admission and the saved test result, in order.',
    lesson: 'The session belongs to the server. A browser connection is only one way to reach it.',
    browser: 'Disconnected', cli: 'Not connected', tool: 'Not called yet', state: 'Work continues', count: 2,
    caption: 'The client connection ends. The server adds a saved fact.',
    rule: '/specification/recovery.html#dasp-core-005', ruleLabel: 'Disconnection does not cancel admitted work',
    messageNote: 'This application update is saved. Temporary progress such as “Running tests” would be a separate progress message and would not advance the saved history.',
    messages: [checks]
  },
  {
    label: 'Retry', title: 'Try the request again. Keep the same intent.',
    text: 'You reopen the app and retry with command ID update-042 and the same input. The server finds its saved admission and returns a duplicate receipt. This retry does not dispatch the work again.',
    clientKnows: 'The command was admitted at update 1. Its final outcome is still unknown.',
    serverKeeps: 'The same two updates. A duplicate creates no new admission.',
    lesson: 'Give each attempt a new request ID. Keep the command ID and data for the same intent.',
    browser: 'Admission confirmed', cli: 'Not connected', tool: 'Not called yet', state: 'Same command', count: 2,
    caption: 'Another request attempt points to the original admission.',
    rule: '/specification/recovery.html#dasp-core-003', ruleLabel: 'Equal retries share one admission',
    messageNote: 'The new attempt has a new CloudEvents ID and request ID. Its command data is unchanged. Changing the input under an admitted command ID would conflict.',
    messages: [event('command', 'request-event-2', web, intent, 'attempt-2'), event('receipt', 'reply-2', host, receipt('duplicate'), 'attempt-2')]
  },
  {
    label: 'Join', title: 'A second client can read the same facts.',
    text: 'A teammate opens an authorized CLI and reads the session from cursor 0. It applies updates 1 and 2, then saves cursor 2 with its local state. The browser has only read a receipt; its applied cursor remains 0.',
    clientKnows: 'The CLI has applied the admission and test result. The browser has not.',
    serverKeeps: 'One ordered history for both clients. Each client keeps its own cursor.',
    lesson: 'A second client can recover the record without taking over the first connection.',
    browser: 'Applied cursor: 0', cli: 'Applied cursor: 2', tool: 'Not called yet', state: 'Shared session', count: 2,
    caption: 'Same history. Different applied positions.',
    rule: '/specification/recovery.html#dasp-core-010', ruleLabel: 'Save the cursor with client state',
    messageNote: 'The replay page contains the original saved events, with their original source and ID. Its wrapper has its own event ID and request ID.',
    messages: [event('updates.read', 'cli-read-1', cli, { session_id: session, after: 0, limit: 10 }, 'cli-replay-1'), event('updates', 'page-1', host, { session_id: session, after: 0, next: 2, head: 2, events: [accepted, checks] }, 'cli-replay-1')]
  },
  {
    label: 'Restart', title: 'The server restarts. What reached the outside world?',
    text: 'The actor asks the Git provider to create a pull request. Its response is lost, then the server process stops. On restart, the saved admission and test result remain. They do not prove whether the pull request exists.',
    clientKnows: 'There is no saved final outcome yet. A restart does not establish failure.',
    serverKeeps: 'The saved record, while it checks the external effect before dispatching more work.',
    lesson: 'Starting again without checking could repeat an external effect.',
    browser: 'Applied cursor: 0', cli: 'Applied cursor: 2', tool: 'Result unknown', state: 'Checking evidence', count: 2,
    caption: 'The server recovers its record. The external effect needs separate evidence.',
    rule: '/specification/recovery.html#dasp-core-007', ruleLabel: 'Check effect evidence after owner loss',
    messageNote: 'There is no generic “restart” wire event in DASP. These are the saved events that survive this illustrative process restart. The host must check effect evidence before dispatch.',
    messages: [accepted, checks]
  },
  {
    label: 'Uncertainty', title: 'An honest unknown is a useful result.',
    text: 'The server cannot confirm whether the pull request was created. It saves an uncertain outcome at update 3 and prevents unsafe repeat execution. The CLI reads that update. The application now needs a defined way to check the external result.',
    clientKnows: 'The command is settled as uncertain. Blind retry is not a recovery plan.',
    serverKeeps: 'One immutable outcome. Later reconciliation cannot rewrite that fact.',
    lesson: 'DASP preserves what is known. Your application must define how external effects are checked.',
    browser: 'Applied cursor: 0', cli: 'Applied cursor: 3', tool: 'Result unknown', state: 'Uncertain outcome', count: 3,
    caption: 'The uncertainty becomes a saved fact that every authorized client can read.',
    rule: '/specification/recovery.html#dasp-core-007', ruleLabel: 'Uncertainty is a terminal outcome',
    messageNote: 'The profile defines the effect_unknown error. A settled outcome read returns the same value as the saved terminal update. Checking the external system later requires a separately specified profile action.',
    messages: [uncertain, event('outcome.read', 'outcome-read-1', web, { session_id: session, command_id: command }, 'outcome-1'), event('outcome', 'outcome-reply-1', host, { session_id: session, command_id: command, state: 'settled', sequence: 3, outcome }, 'outcome-1')]
  }
];
