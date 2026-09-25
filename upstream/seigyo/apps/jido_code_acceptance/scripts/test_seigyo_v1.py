"""Independent, hand-reviewed v1 examples. Run with SEIGYO_CONTRACT set."""

import copy
import json
import os
from pathlib import Path
import unittest

from seigyo_v1 import Contract, Invalid, decode_json, envelope, uuid7, validate_schema

BUNDLE = Path(os.environ['SEIGYO_CONTRACT'])
SESSION = 'ses_01994770-1234-7000-8000-000000000001'
COMMAND = 'cmd_01994770-1234-7000-8000-000000000002'
RESULT = 'res_01994770-1234-7000-8000-000000000003'


def result_data():
    return {
        'version': 1, 'result_id': RESULT, 'session_id': SESSION,
        'command_id': COMMAND, 'completion': 'execution', 'status': 'completed',
        'config_revision': 0, 'config_digest': 'a' * 64, 'context_revision': 0,
        'tool_profile': {'id': 'coding', 'version': '1', 'digest': 'b' * 64},
        'model_id': 'test:model',
        'blocks': [{'type': 'markdown', 'text': 'Ready', 'truncated': False}],
        'usage': {'measurement': 'unavailable', 'input_tokens': None,
                  'output_tokens': None, 'reasoning_tokens': None,
                  'cache_read_tokens': None, 'cache_write_tokens': None,
                  'model_calls': 1, 'delegated_runs': 0},
        'reasoning': {'visibility': 'hidden', 'summary': None, 'truncated': False},
        'error': None,
    }


def page_data():
    return {
        'version': 1, 'session_id': SESSION, 'after_sequence': 0, 'next_cursor': None,
        'updates': [
            {'version': 1, 'session_id': SESSION, 'command_id': COMMAND,
             'sequence': 1, 'kind': 'event', 'event_type': 'command_accepted',
             'payload': {'kind': 'submit_text', 'state': 'active'}},
            {'version': 1, 'session_id': SESSION, 'command_id': COMMAND,
             'sequence': 2, 'kind': 'event', 'event_type': 'command_completed',
             'payload': {'result_id': RESULT}},
        ],
    }


class ContractTests(unittest.TestCase):
    def test_custom_json_byte_limit_counts_encoded_utf8(self):
        schema = {'type': 'string', 'x-seigyo-maxJsonBytes': 4}
        validate_schema('é', schema)
        with self.assertRaises(Invalid):
            validate_schema('界', schema)

    def test_reserved_reference_branches_still_validate_their_custom_constraints(self):
        invalid_blocks = [
            {'type': 'artifact', 'artifact_id': 'art_' + uuid7(), 'name': '', 'media_type': 'text/plain'},
            {'type': 'artifact', 'artifact_id': 'art_' + uuid7(), 'name': 'ok', 'media_type': 'not a media type'},
            {'type': 'citation', 'uri': '', 'title': 'ok'},
            {'type': 'citation', 'uri': 'https://example.test', 'title': '界' * 86},
        ]
        for block in invalid_blocks:
            data = result_data()
            data['blocks'] = [block]
            with self.subTest(block=block), self.assertRaises(Invalid):
                self.check('result', data)
        data = result_data()
        data['tool_profile']['id'] = ''
        with self.assertRaises(Invalid):
            self.check('result', data)

    def test_failure_fields_cannot_be_arbitrary_provider_text(self):
        for field in ['private provider details', 'A', 'a' * 65]:
            with self.subTest(field=field), self.assertRaises(Invalid):
                self.check('failure', {'version': 1, 'code': 'unavailable', 'field': field})

    @classmethod
    def setUpClass(cls):
        cls.contract = Contract(BUNDLE)

    def check(self, name, data, role='result'):
        self.contract.signal(envelope(name, data, role), name, role)

    def test_published_vectors(self):
        for vector in json.loads((BUNDLE / 'vectors.json').read_text()):
            with self.subTest(vector=vector['name']):
                if vector['valid']:
                    self.check(vector['type'], vector['data'], 'request')
                else:
                    with self.assertRaises(Invalid):
                        self.check(vector['type'], vector['data'], 'request')

    def test_hand_reviewed_result(self):
        self.check('result', result_data())
        for status in ['completed', 'cancelled', 'failed', 'uncertain']:
            for has_error in [False, True]:
                data = result_data()
                data['status'] = status
                data['error'] = {'version': 1, 'code': 'unavailable', 'field': None} if has_error else None
                valid = has_error == (status in ['failed', 'uncertain'])
                with self.subTest(status=status, error=has_error):
                    if valid:
                        self.check('result', data)
                    else:
                        with self.assertRaises(Invalid):
                            self.check('result', data)

    def test_result_schema_alone_does_not_prove_validity(self):
        # Deliberate decoder defect: schema-only validation accepts this value.
        data = result_data()
        data['status'] = 'uncertain'
        message = envelope('result', data, 'result')
        validate_schema(message, self.contract.schemas['jido.client.v1.result']['schema'])
        with self.assertRaises(Invalid):
            self.contract.signal(message, 'result', 'result')

    def test_utf8_boundary_counts_bytes(self):
        for text, valid in [('界' * 10922 + 'ab', True), ('界' * 10923, False)]:
            data = result_data()
            data['blocks'][0]['text'] = text
            with self.subTest(bytes=len(text.encode('utf-8'))):
                if valid:
                    self.check('result', data)
                else:
                    with self.assertRaises(Invalid):
                        self.check('result', data)

    def test_usage_requires_coherent_measurement(self):
        fields = ['input_tokens', 'output_tokens', 'reasoning_tokens',
                  'cache_read_tokens', 'cache_write_tokens']
        for mode in ['reported', 'estimated', 'mixed', 'unavailable']:
            for count in range(6):
                data = result_data()
                data['usage']['measurement'] = mode
                for field in fields[:count]:
                    data['usage'][field] = 0
                valid = (mode == 'unavailable' and count == 0 or
                         mode in ['reported', 'estimated'] and count == 5 or
                         mode == 'mixed' and count > 0)
                with self.subTest(mode=mode, count=count):
                    if valid:
                        self.check('result', data)
                    else:
                        with self.assertRaises(Invalid):
                            self.check('result', data)

    def test_hidden_reasoning_cannot_contain_text(self):
        data = result_data()
        data['reasoning']['summary'] = 'private'
        with self.assertRaises(Invalid):
            self.check('result', data)

    def test_result_rejects_unknown_union_and_bad_provenance(self):
        for path, value in [(['blocks', 0, 'type'], 'future'),
                            (['config_digest'], 'A' * 64),
                            (['command_id'], SESSION),
                            (['usage', 'input_tokens'], 9007199254740992),
                            (['config_revision'], True),
                            (['version'], True)]:
            data = result_data()
            target = data
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            with self.subTest(path=path), self.assertRaises(Invalid):
                self.check('result', data)

    def test_replay_is_contiguous_and_has_one_session(self):
        self.check('updates.page', page_data())
        mutations = [lambda d: d['updates'][1].update(sequence=3),
                     lambda d: d['updates'][0].update(sequence=2),
                     lambda d: d['updates'][1].update(session_id='ses_' + uuid7()),
                     lambda d: d.update(next_cursor=1),
                     lambda d: d.update(updates=[] , next_cursor=0),
                     lambda d: d['updates'].reverse()]
        for mutate in mutations:
            data = page_data()
            mutate(data)
            with self.assertRaises(Invalid):
                self.check('updates.page', data)

    def test_unknown_role_and_wrong_envelope_fail(self):
        message = envelope('result', result_data(), 'request')
        with self.assertRaises(Invalid):
            self.contract.signal(message, 'result', 'result')
        message = envelope('result', result_data(), 'result')
        for field, value in [('source', '/internal'), ('type', 'jido.internal.run'),
                             ('id', COMMAND), ('extra', True)]:
            bad = {**message, field: value}
            with self.subTest(field=field), self.assertRaises(Invalid):
                self.contract.signal(bad, 'result', 'result')

    def test_published_x_seigyo_byte_annotation_is_enforced(self):
        schema = self.contract.operations['controls'][0]['args_schema']
        valid = {'session_id': SESSION, 'request_ref': '界' * 42 + 'ab'}
        validate_schema(valid, schema)
        with self.assertRaises(Invalid):
            validate_schema({**valid, 'request_ref': '界' * 43}, schema)
        with self.assertRaises(Invalid):
            validate_schema('ok', {'type': 'string', 'x-seigyo-unknown': True})

    def test_json_rejects_ambiguous_or_nonportable_values(self):
        for raw in ['{"a":1,"a":2}', '1.0', 'NaN', 'Infinity',
                    '9007199254740992', '"\\ud800"', '"\\udfff"']:
            with self.subTest(raw=raw), self.assertRaises(Invalid):
                decode_json(raw.encode())
        self.assertEqual(decode_json(b'{"n":9007199254740991}'), {'n': 9007199254740991})

    def test_ids_have_uuid7_version_and_variant(self):
        import re
        ids = {uuid7() for _ in range(500)}
        self.assertEqual(len(ids), 500)
        pattern = self.contract.operations['validation']['id_patterns']['signal']
        self.assertTrue(all(re.fullmatch(pattern, value) for value in ids))


if __name__ == '__main__':
    unittest.main()
