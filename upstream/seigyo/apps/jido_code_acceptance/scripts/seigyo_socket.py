"""Small RFC 6455 text client for the independent verifier. Standard library only.

No extensions, compression, redirects, alternate transports, or protocol modules.
Reads have one absolute deadline, including fragmented messages and control frames.
"""

import base64
import hashlib
import json
import secrets
import socket
import ssl
import struct
import time
from urllib.parse import urlsplit, urlencode

from seigyo_v1 import decode_json, require


class WebSocket:
    def __init__(self, url, token, timeout=30, limit=524288):
        uri = urlsplit(url)
        require(uri.scheme in ['http', 'https', 'ws', 'wss'] and uri.hostname
                and not uri.username and not uri.password and not uri.query and not uri.fragment,
                'invalid endpoint URL')
        secure = uri.scheme in ['https', 'wss']
        port = uri.port or (443 if secure else 80)
        self.limit = limit
        self.deadline = time.monotonic() + timeout
        self.socket = socket.create_connection((uri.hostname, port), timeout=timeout)
        try:
            if secure:
                self.socket = ssl.create_default_context().wrap_socket(
                    self.socket, server_hostname=uri.hostname)
            path = uri.path.rstrip('/')
            if not path.endswith('/client/socket/websocket'):
                path += '/client/socket/websocket'
            path += '?' + urlencode({'token': token, 'vsn': '2.0.0'})
            nonce = base64.b64encode(secrets.token_bytes(16)).decode('ascii')
            host = '[' + uri.hostname + ']' if ':' in uri.hostname else uri.hostname
            request = (f'GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\n'
                       f'Upgrade: websocket\r\nConnection: Upgrade\r\n'
                       f'Sec-WebSocket-Key: {nonce}\r\nSec-WebSocket-Version: 13\r\n\r\n')
            self.socket.sendall(request.encode('ascii'))
            raw = bytearray()
            while not raw.endswith(b'\r\n\r\n'):
                require(len(raw) < 16384, 'HTTP header limit')
                raw.extend(self.exact(1))
            lines = raw.decode('ascii').split('\r\n')
            require(lines[0].split()[:2] == ['HTTP/1.1', '101'], 'WebSocket upgrade rejected')
            headers = {}
            for line in lines[1:-2]:
                key, value = line.split(':', 1)
                key = key.lower()
                require(key not in headers, 'duplicate upgrade header')
                headers[key] = value.strip()
            expected = base64.b64encode(hashlib.sha1(
                (nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode('ascii')).digest()).decode()
            require(headers.get('sec-websocket-accept') == expected, 'invalid WebSocket accept')
            require(headers.get('upgrade', '').lower() == 'websocket'
                    and 'upgrade' in [v.strip() for v in headers.get('connection', '').lower().split(',')],
                    'invalid upgrade headers')
            require('sec-websocket-extensions' not in headers
                    and 'sec-websocket-protocol' not in headers, 'unrequested WebSocket extension')
        except BaseException:
            self.socket.close()
            raise

    def exact(self, count):
        data = bytearray()
        while len(data) < count:
            remaining = self.deadline - time.monotonic()
            require(remaining > 0, 'endpoint deadline')
            self.socket.settimeout(remaining)
            chunk = self.socket.recv(count - len(data))
            require(bool(chunk), 'unexpected socket EOF')
            data.extend(chunk)
        return bytes(data)

    def send_bytes(self, payload, opcode=1):
        require(len(payload) <= self.limit, 'outgoing WebSocket frame limit')
        header = bytes([0x80 | opcode])
        if len(payload) < 126:
            header += bytes([0x80 | len(payload)])
        elif len(payload) < 65536:
            header += b'\xfe' + struct.pack('!H', len(payload))
        else:
            header += b'\xff' + struct.pack('!Q', len(payload))
        mask = secrets.token_bytes(4)
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.socket.sendall(header + mask + masked)

    def send(self, value):
        self.send_bytes(json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode('utf-8'))

    def receive(self):
        message = bytearray()
        started = False
        for _ in range(1024):
            first, second = self.exact(2)
            final, opcode = bool(first & 0x80), first & 0x0f
            require(first & 0x70 == 0 and second & 0x80 == 0, 'invalid server frame flags')
            size = second & 0x7f
            if size == 126:
                size = struct.unpack('!H', self.exact(2))[0]
                require(size >= 126, 'nonminimal WebSocket length')
            elif size == 127:
                size = struct.unpack('!Q', self.exact(8))[0]
                require(size >= 65536 and size < 2**63, 'invalid WebSocket length')
            require(size <= self.limit, 'incoming WebSocket frame limit')
            if opcode >= 8:
                require(final and size <= 125 and opcode in [8, 9, 10], 'invalid control frame')
                payload = self.exact(size)
                require(opcode != 8, 'server closed WebSocket')
                if opcode == 9:
                    self.send_bytes(payload, opcode=10)
                continue
            require(opcode == (0 if started else 1), 'invalid text fragment order')
            require(len(message) + size <= self.limit, 'WebSocket message limit')
            message.extend(self.exact(size))
            started = True
            if final:
                return decode_json(bytes(message))
        require(False, 'WebSocket fragment/control limit')

    def close(self):
        try:
            self.send_bytes(b'\x03\xe8', opcode=8)
        except OSError:
            pass
        finally:
            self.socket.close()
