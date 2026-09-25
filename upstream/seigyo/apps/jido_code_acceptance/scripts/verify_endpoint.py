"""Independent Python journey. Run --help; credentials come from an environment variable."""

import argparse
import json
import os
from pathlib import Path
import sys
import time

from seigyo_v1 import Contract, Invalid, decode_json, envelope, require, uuid7, validate_schema
from seigyo_socket import WebSocket


class Peer:
    def __init__(self, args, contract, token):
        self.contract = contract
        self.socket = WebSocket(args.url, token, timeout=args.timeout)
        self.counter = 1
        try:
            offer = {'versions': [1], 'profile': {'id': 'coding', 'versions': [1]},
                     'required_features': ['seigyo.core/1'], 'optional_features': []}
            schema = decode_json(args.initialization_schema.read_bytes())
            validate_schema(offer, schema['offer'])
            self.socket.send(['1', '1', 'client:v1', 'phx_join', offer])
            response = self.reply('1')
            require(response['status'] == 'ok', 'initialization rejected')
            selection = response['response']
            validate_schema(selection, schema['selection'])
            require(selection['version'] == 1 and selection['profile'] == {
                'id': 'coding', 'version': 1, 'digest': contract.identity['digest']},
                'wrong selected contract')
            require(selection['features'] == ['seigyo.core/1'], 'unoffered selected feature')
            expected = dict(contract.operations['capabilities'])
            expected['controls'] = [x for x in expected['controls'] if x != 'watch_progress']
            expected['push_signal_types'] = [x for x in expected['push_signal_types']
                                              if x != 'jido.client.v1.progress']
            capabilities = dict(selection['capabilities'])
            principal = capabilities.pop('principal', None)
            require(type(principal) is str and principal, 'missing principal')
            require(capabilities == expected, 'selected capability mismatch')
            for key, limit in selection['limits'].items():
                require(key in contract.limits and 0 < limit <= contract.limits[key], 'invalid limit')
            contract.limits.update(selection['limits'])
            self.socket.limit = contract.limits['websocket_frame_bytes']
        except BaseException:
            self.socket.close()
            raise

    def reply(self, ref):
        frame = self.socket.receive()
        require(type(frame) is list and len(frame) == 5
                and frame[:4] == ['1', ref, 'client:v1', 'phx_reply'], 'reply correlation')
        payload = frame[4]
        require(type(payload) is dict and set(payload) == {'status', 'response'}
                and payload['status'] in ['ok', 'error'], 'reply shape')
        return payload

    def call(self, op, expected, data, request_type=None):
        self.counter += 1
        ref = str(self.counter)
        body = {'op': op, 'request_ref': ref}
        if request_type:
            signal = envelope(request_type, data, 'request')
            self.contract.signal(signal, request_type, 'request')
            body['signal'] = signal
        else:
            body['args'] = data
        self.socket.send(['1', ref, 'client:v1', 'call', body])
        reply = self.reply(ref)
        response = reply['response']
        key = 'result' if reply['status'] == 'ok' else 'failure'
        require(type(response) is dict and set(response) == {'request_ref', key}
                and response['request_ref'] == ref, 'request correlation')
        name = expected if key == 'result' else 'failure'
        result = self.contract.signal(response[key], name, 'result')
        require(key == 'result', 'operation rejected')
        return result

    def close(self):
        self.socket.close()


def journey(args, contract, token, report):
    session_id = 'ses_' + uuid7()
    command_id = 'cmd_' + uuid7()
    opening = {'version': 1, 'session_id': session_id, 'workspace_id': None}
    command = {'version': 1, 'id': command_id, 'session_id': session_id,
               'kind': 'submit_text', 'input': {'text': args.text}}
    peer = Peer(args, contract, token)
    try:
        report['passes'].append('initialize')
        opened = peer.call('open', 'session.opened', opening, 'session.open')
        require(opened['session_id'] == session_id, 'opened Session mismatch')
        report['passes'].append('open')
        receipt = peer.call('submit', 'receipt', command, 'command')
        require(receipt['session_id'] == session_id and receipt['command_id'] == command_id
                and receipt['disposition'] == 'accepted' and receipt['error'] is None,
                'admission mismatch')
        report['passes'].append('submit')
    finally:
        peer.close()
    peer = Peer(args, contract, token)
    try:
        reopened = peer.call('open', 'session.opened', opening, 'session.open')
        require(reopened == opened, 'reopened Session changed')
        report['passes'].append('reconnect')
        duplicate = peer.call('submit', 'receipt', command, 'command')
        expected_duplicate = dict(receipt, disposition='duplicate')
        require(duplicate == expected_duplicate, 'retry changed saved admission')
        report['passes'].append('duplicate')
        updates = []
        cursor = 0
        terminal = None
        while terminal is None:
            page = peer.call('updates', 'updates.page',
                             {'session_id': session_id, 'after_sequence': cursor, 'limit': 1})
            require(page['session_id'] == session_id and page['after_sequence'] == cursor,
                    'page request identity')
            for update in page['updates']:
                require(update['command_id'] == command_id, 'unexpected Command in new Session')
                updates.append(update)
                cursor = update['sequence']
                if update['event_type'] in ['command_completed', 'command_failed',
                                            'command_cancelled', 'command_uncertain']:
                    terminal = update
            if not page['updates']:
                time.sleep(0.02)
        require([x['event_type'] for x in updates] == ['command_accepted', 'command_completed'],
                'unexpected outcome sequence')
        report['passes'].append('replay')
        read = {'session_id': session_id, 'command_id': command_id}
        result = peer.call('result', 'result', read)
        require(result['session_id'] == session_id and result['command_id'] == command_id
                and result['result_id'] == terminal['payload']['result_id']
                and result['status'] == 'completed', 'Result identity or status mismatch')
        if args.expected_text is not None:
            require([b['text'] for b in result['blocks'] if b['type'] == 'markdown']
                    == [args.expected_text], 'Result text mismatch')
        report['passes'].append('result')
        require(peer.call('result', 'result', read) == result, 'Result changed')
        require(peer.call('submit', 'receipt', command, 'command') == duplicate,
                'terminal retry changed admission')
        report['passes'].append('immutable_result')
    finally:
        peer.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--initialization-schema', type=Path, required=True)
    parser.add_argument('--digest', help='Trusted expected contract digest')
    parser.add_argument('--url', required=True)
    parser.add_argument('--token-env', default='SEIGYO_TOKEN')
    parser.add_argument('--implementation-revision', required=True)
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--text', default='Reply briefly to confirm this protocol test.')
    parser.add_argument('--expected-text')
    args = parser.parse_args()
    report = {'profile': 'coding', 'binding': 'phoenix-channel-websocket',
              'contract_digest': None, 'implementation_revision': args.implementation_revision,
              'passes': [], 'failures': [], 'skips': [], 'scope': 'second-language journey'}
    try:
        require(0 < args.timeout <= 300, 'invalid timeout')
        token = os.environ.get(args.token_env)
        require(bool(token), 'missing token environment variable')
        contract = Contract(args.contract, args.digest)
        report['contract_digest'] = contract.identity['digest']
        journey(args, contract, token, report)
    except Exception as error:
        report['failures'].append(str(error) if isinstance(error, Invalid) else type(error).__name__)
    print(json.dumps(report, sort_keys=True))
    return int(bool(report['failures']))


if __name__ == '__main__':
    sys.exit(main())
