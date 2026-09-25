"""Hand-written WebSocket frames test the independent transport's loss bounds."""

import socket
import struct
import time
import unittest

from seigyo_v1 import Invalid
from seigyo_socket import WebSocket


class SocketTests(unittest.TestCase):
    def setUp(self):
        left, right = socket.socketpair()
        self.addCleanup(left.close)
        self.addCleanup(right.close)
        self.peer = right
        self.client = WebSocket.__new__(WebSocket)
        self.client.socket = left
        self.client.deadline = time.monotonic() + 2
        self.client.limit = 100

    def test_fragmented_text_with_ping(self):
        self.peer.sendall(b'\x01\x03[1,' + b'\x89\x02hi' + b'\x80\x022]')
        self.assertEqual(self.client.receive(), [1, 2])
        response = self.peer.recv(20)
        self.assertEqual(response[:2], b'\x8a\x82')
        mask = response[2:6]
        self.assertEqual(bytes(x ^ mask[i % 4] for i, x in enumerate(response[6:])), b'hi')

    def test_oversize_is_rejected_before_reading_the_body(self):
        self.peer.sendall(b'\x81\x7f' + struct.pack('!Q', 2**40))
        with self.assertRaisesRegex(Invalid, 'frame limit'):
            self.client.receive()

    def test_invalid_flags_and_fragment_order(self):
        for header in [b'\x81\x80', b'\xc1\x00', b'\x80\x00', b'\x82\x00', b'\x09\x00']:
            with self.subTest(header=header):
                self.peer.sendall(header)
                with self.assertRaises(Invalid):
                    self.client.receive()

    def test_aggregate_fragment_limit(self):
        self.peer.sendall(b'\x01\x40' + b' ' * 64 + b'\x80\x40')
        with self.assertRaisesRegex(Invalid, 'message limit'):
            self.client.receive()

    def test_masked_client_text(self):
        self.client.send({'text': 'é'})
        raw = self.peer.recv(100)
        self.assertEqual(raw[0], 0x81)
        self.assertTrue(raw[1] & 0x80)
        mask, payload = raw[2:6], raw[6:]
        self.assertEqual(bytes(x ^ mask[i % 4] for i, x in enumerate(payload)),
                         '{"text":"é"}'.encode())

    def test_invalid_utf8(self):
        self.peer.sendall(b'\x81\x01\xff')
        with self.assertRaises(Invalid):
            self.client.receive()
