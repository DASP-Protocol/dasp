"""Independent coding v1 checks. Uses published JSON and Python's standard library.

This module checks the message subset used by the second-language scenario.
It rejects other Signal types instead of claiming full protocol coverage.
"""

import json
import re
import secrets
import time
import uuid

from verify_contract import verify

SAFE_INTEGER = 9007199254740991
PREFIX = 'jido.client.v1.'


class Invalid(ValueError):
    """A public protocol assertion failed. Messages do not include wire content."""


def require(condition, rule):
    if not condition:
        raise Invalid(rule)


def utf8(value):
    try:
        return value.encode('utf-8')
    except (AttributeError, UnicodeError) as error:
        raise Invalid('invalid UTF-8 string') from error


def portable(value):
    if value is None or type(value) is bool:
        return
    if type(value) is int:
        require(abs(value) <= SAFE_INTEGER, 'unsafe JSON integer')
    elif type(value) is str:
        utf8(value)
    elif type(value) is list:
        for item in value:
            portable(item)
    elif type(value) is dict:
        for key, item in value.items():
            require(type(key) is str, 'JSON key must be a string')
            utf8(key)
            portable(item)
    else:
        raise Invalid('unsupported JSON value')


def decode_json(raw):
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, 'duplicate JSON key')
            value[key] = item
        return value

    def not_integer(_value):
        raise Invalid('JSON numbers must be safe integers')

    try:
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
                           parse_float=not_integer, parse_constant=not_integer)
        portable(value)
        return value
    except (UnicodeError, RecursionError, json.JSONDecodeError) as error:
        raise Invalid('invalid JSON') from error


def equal(left, right):
    # Python equates True with 1; JSON Schema does not.
    return type(left) is type(right) and left == right


def validate_schema(value, schema):
    """The closed JSON Schema subset used by the frozen release, plus byte caps."""
    allowed = {'$schema', 'description', 'discriminator', 'type', 'const', 'enum',
               'properties', 'required', 'additionalProperties', 'items',
               'minItems', 'maxItems', 'minLength', 'maxLength', 'minimum',
               'maximum', 'pattern', 'oneOf', 'anyOf', 'uniqueItems',
               'x-seigyo-maxUtf8Bytes', 'x-seigyo-maxJsonBytes'}
    require(not (set(schema) - allowed), 'unsupported schema keyword')
    if 'x-seigyo-maxJsonBytes' in schema:
        require(len(json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode('utf-8'))
                <= schema['x-seigyo-maxJsonBytes'], 'JSON byte limit')
    if 'const' in schema:
        require(equal(value, schema['const']), 'constant mismatch')
    if 'enum' in schema:
        require(any(equal(value, item) for item in schema['enum']), 'unknown enum value')
    types = {'object': dict, 'array': list, 'string': str, 'integer': int,
             'boolean': bool, 'null': type(None)}
    if 'type' in schema:
        require(schema['type'] in types, 'unsupported schema type')
        require(type(value) is types[schema['type']], 'wrong JSON type')
    for union in ['oneOf', 'anyOf']:
        if union in schema:
            matches = 0
            for branch in schema[union]:
                try:
                    validate_schema(value, branch)
                    matches += 1
                except Invalid:
                    pass
            require(matches == 1 if union == 'oneOf' else matches > 0, 'invalid union')
    if type(value) is dict:
        require(set(schema.get('required', [])) <= set(value), 'missing object field')
        properties = schema.get('properties', {})
        if schema.get('additionalProperties') is False:
            require(set(value) <= set(properties), 'unknown object field')
        for name in set(value) & set(properties):
            validate_schema(value[name], properties[name])
    if type(value) is list:
        require(len(value) >= schema.get('minItems', 0), 'too few items')
        require(len(value) <= schema.get('maxItems', len(value)), 'too many items')
        if schema.get('uniqueItems'):
            encoded = [json.dumps(item, sort_keys=True) for item in value]
            require(len(encoded) == len(set(encoded)), 'duplicate items')
        if 'items' in schema:
            for item in value:
                validate_schema(item, schema['items'])
    if type(value) is str:
        require(len(value) >= schema.get('minLength', 0), 'string too short')
        require(len(value) <= schema.get('maxLength', len(value)), 'string too long')
        if 'pattern' in schema:
            require(re.search(schema['pattern'], value) is not None, 'pattern mismatch')
        if 'x-seigyo-maxUtf8Bytes' in schema:
            require(len(utf8(value)) <= schema['x-seigyo-maxUtf8Bytes'], 'UTF-8 byte limit')
    if type(value) is int:
        require(value >= schema.get('minimum', value), 'integer below minimum')
        require(value <= schema.get('maximum', value), 'integer above maximum')


def uuid7():
    number = (int(time.time() * 1000) << 80) | (7 << 76)
    number |= secrets.randbits(12) << 64 | (2 << 62) | secrets.randbits(62)
    return str(uuid.UUID(int=number))


def envelope(name, data, role):
    return {'specversion': '1.0', 'id': uuid7(),
            'source': '/jido/code/client' if role == 'request' else '/jido/code/server',
            'type': name if name.startswith(PREFIX) else PREFIX + name, 'data': data}


class Contract:
    def __init__(self, root, digest=None):
        self.identity = verify(root, digest)
        require(self.identity['profile'] == 'coding', 'unsupported profile')
        self.schemas = decode_json((root / 'schemas.json').read_bytes())['signals']
        self.operations = decode_json((root / 'operations.json').read_bytes())
        self.limits = self.operations['limits']
        self.patterns = self.operations['validation']['id_patterns']

    def signal(self, message, expected, role):
        name = expected if expected.startswith(PREFIX) else PREFIX + expected
        supported = {'session.open', 'session.opened', 'command', 'receipt',
                     'updates.page', 'update', 'result', 'failure'}
        require(name.removeprefix(PREFIX) in supported, 'unchecked Signal type')
        require(type(message) is dict and message.get('type') == name, 'wrong Signal type')
        require(self.schemas[name]['role'] == role, 'wrong Signal role')
        portable(message)
        require(len(json.dumps(message, ensure_ascii=False, separators=(',', ':')).encode())
                <= self.limits['signal_json_bytes'], 'Signal byte limit')
        validate_schema(message, self.schemas[name]['schema'])
        data = message['data']
        self.identities(data)
        if name == PREFIX + 'command':
            self.identity_field(data['id'], 'command')
            self.text(data['input']['text'], self.limits['command_text_bytes'], nonblank=True)
            if 'model' in data['input']:
                self.text(data['input']['model'], 256, nonblank=True, controls=False)
        elif name == PREFIX + 'updates.page':
            self.page(data)
        elif name == PREFIX + 'result':
            self.result(data)
        if name == PREFIX + 'failure':
            self.failure(data)
        elif data.get('error') is not None:
            self.failure(data['error'])
        return data

    def identity_field(self, value, kind):
        require(type(value) is str and re.fullmatch(self.patterns[kind], value),
                'invalid ' + kind + ' identity')

    def identities(self, value):
        if type(value) is dict:
            for key, item in value.items():
                kind = key.removesuffix('_id')
                if key.endswith('_id') and kind in self.patterns and item is not None:
                    self.identity_field(item, kind)
                if key == 'attachment_ids':
                    for attachment in item:
                        self.identity_field(attachment, 'attachment')
                self.identities(item)
        elif type(value) is list:
            for item in value:
                self.identities(item)

    def text(self, value, limit, nonblank=False, controls=True):
        require(len(utf8(value)) <= limit, 'UTF-8 byte limit')
        require(not nonblank or value.strip(), 'blank string')
        require(controls or not re.search(r'[\x00-\x1f\x7f]', value), 'control character')

    def reference(self, value):
        self.text(value, 256, controls=False)
        require(value != '', 'empty reference')

    def failure(self, data):
        field = data['field']
        require(field is None or (len(utf8(field)) <= 64 and re.fullmatch('[a-z][a-z0-9_]*', field)),
                'invalid error field')

    def page(self, data):
        updates = data['updates']
        require(len(updates) <= self.limits['page_items'], 'page item limit')
        require(len(json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode())
                <= self.limits['updates_page_json_bytes'], 'page byte limit')
        expected = data['after_sequence'] + 1
        for update in updates:
            require(update['session_id'] == data['session_id'], 'mixed Session page')
            require(update['sequence'] == expected, 'noncontiguous replay')
            expected += 1
        cursor = data['next_cursor']
        require(cursor is None or (updates and cursor == updates[-1]['sequence']),
                'page cursor mismatch')

    def result(self, data):
        require((data['error'] is not None) == (data['status'] in ['failed', 'uncertain']),
                'Result error/status mismatch')
        for digest in [data['config_digest'], data['tool_profile']['digest']]:
            require(re.fullmatch('[0-9a-f]{64}', digest), 'invalid SHA-256')
        self.reference(data['tool_profile']['id'])
        self.reference(data['tool_profile']['version'])
        if data['model_id'] is not None:
            self.text(data['model_id'], 256, nonblank=True, controls=False)
        reasoning = data['reasoning']
        require((reasoning['visibility'] == 'hidden') == (reasoning['summary'] is None),
                'reasoning visibility mismatch')
        if reasoning['summary'] is not None:
            self.text(reasoning['summary'], 16384)
        usage = data['usage']
        known = sum(usage[key] is not None for key in
                    ['input_tokens', 'output_tokens', 'reasoning_tokens',
                     'cache_read_tokens', 'cache_write_tokens'])
        allowed = {'unavailable': [0], 'reported': [5], 'estimated': [5], 'mixed': range(1, 6)}
        require(known in allowed[usage['measurement']], 'usage measurement mismatch')
        for block in data['blocks']:
            if block['type'] == 'markdown':
                self.text(block['text'], self.limits['result_text_bytes'])
            elif block['type'] == 'artifact':
                self.reference(block['name'])
                self.text(block['media_type'], 128)
                require(re.fullmatch(r'[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*',
                                     block['media_type']), 'invalid media type')
            elif block['type'] == 'citation':
                self.reference(block['uri'])
                self.reference(block['title'])
        cost = sum(128 + sum(len(utf8(v)) for v in block.values() if type(v) is str)
                   for block in data['blocks'])
        require(cost <= self.limits['result_blocks_json_bytes'], 'Result block budget')
