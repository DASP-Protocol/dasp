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
    id: 'lost-reply', title: 'The reply is lost.',
    text: 'The server accepts the command, but its reply never reaches your app. You close the browser. The agent continues, runs the tests, and the server saves the result.',
    benefit: 'A lost connection does not cancel accepted work. The server keeps the record.',
    count: 2, caption: 'Your app sees a timeout. The server has two saved facts.',
    rule: '/specification/recovery.html#dasp-core-004', ruleLabel: 'Save admission before acceptance',
    messageNote: 'An authorized session is already open. The server saves admission before it returns an accepted receipt. Here, that reply is lost. The later test result is a saved application update; temporary progress would not add to this history.',
    messages: [submit, accepted, event('receipt', 'reply-1', host, receipt('accepted'), 'attempt-1'), checks]
  },
  {
    id: 'safe-retry', title: 'Retry the same command.',
    text: 'You reopen the app. It sends the same command ID and input again. The server finds the original command and confirms that it was accepted. This retry does not start another copy of the work.',
    benefit: 'The app can recover a lost reply without creating a second command.',
    count: 2, caption: 'Two attempts. One accepted command. The record is unchanged.',
    rule: '/specification/recovery.html#dasp-core-003', ruleLabel: 'Equal retries share one admission',
    messageNote: 'Each attempt has a new CloudEvents ID and request ID. The command ID and command data stay the same. The duplicate receipt points to admission at update 1. It does not report completion or advance the client’s applied position.',
    messages: [event('command', 'request-event-2', web, intent, 'attempt-2'), event('receipt', 'reply-2', host, receipt('duplicate'), 'attempt-2')]
  },
  {
    id: 'shared-history', title: 'A teammate joins.',
    text: 'A teammate opens a command-line tool with access to the session. It reads the saved updates and sees that the tests passed. Your app can read those same updates when it is ready.',
    benefit: 'Each client can catch up from its own saved position.',
    count: 2, caption: 'Both clients use one history. They can read it at different times.',
    rule: '/specification/recovery.html#dasp-core-010', ruleLabel: 'Save the cursor with client state',
    messageNote: 'The CLI applies updates 1 and 2, then saves cursor 2 with its local state. A cursor is the last update a client applied. The web app has only received a receipt, so its cursor remains 0. Replay preserves each saved event’s original source and ID.',
    messages: [event('updates.read', 'cli-read-1', cli, { session_id: session, after: 0, limit: 10 }, 'cli-replay-1'), event('updates', 'page-1', host, { session_id: session, after: 0, next: 2, head: 2, events: [accepted, checks] }, 'cli-replay-1')]
  },
  {
    id: 'server-restart', title: 'The server restarts.',
    text: 'The agent asks the Git provider to create a pull request. The response is lost, then the server stops. After restart, the saved record remains. If the server cannot confirm the external result, it records an uncertain outcome.',
    benefit: 'The server must check what happened before it risks repeating an external action.',
    count: 3, caption: 'The saved result says “uncertain.” It does not claim success or failure.',
    rule: '/specification/recovery.html#dasp-core-007', ruleLabel: 'Check effect evidence after owner loss',
    messageNote: 'The server cannot establish the external effect in this example. It saves a terminal uncertain outcome and prevents unsafe re-execution. The CLI applies update 3. An outcome read returns the same saved result, but does not advance the web app’s cursor. Later checks need a separate profile action; the original outcome cannot change.',
    messages: [uncertain, event('outcome.read', 'outcome-read-1', web, { session_id: session, command_id: command }, 'outcome-1'), event('outcome', 'outcome-reply-1', host, { session_id: session, command_id: command, state: 'settled', sequence: 3, outcome }, 'outcome-1')]
  }
];
