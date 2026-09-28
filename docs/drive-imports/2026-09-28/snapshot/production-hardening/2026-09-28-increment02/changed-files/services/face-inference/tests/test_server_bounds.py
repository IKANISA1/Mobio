"""Real local HTTP/socket tests, explicitly with a fake model, not recognition QA."""
import http.client
import json
from pathlib import Path
import socket
import sys
import threading
import time
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import create_server
from protocol import CaptureError


class FixtureModel:
    dimensions = 3
    contract = {'version': 'fixture-only-not-a-real-model'}
    def __init__(self):
        self.calls = 0
        self.started = threading.Event()
        self.release = threading.Event()
    def embed(self, data):
        self.calls += 1
        if data == b'block':
            self.started.set()
            self.release.wait(2)
        if data == b'error':
            raise RuntimeError('private biometric details')
        if data == b'no-face':
            raise CaptureError('NO_FACE')
        return {'embedding': [1, 0, 0]}


class ServerBounds(unittest.TestCase):
    def setUp(self):
        self.model = FixtureModel()
        self.server = create_server(('127.0.0.1', 0), model=self.model, workers=1, request_timeout=0.3)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': 0.01})
        self.thread.start()
        self.port = self.server.server_port
    def tearDown(self):
        self.model.release.set()
        self.server.shutdown(); self.server.server_close(); self.thread.join(timeout=2)
    def request(self, method, path, body=None):
        c = http.client.HTTPConnection('127.0.0.1', self.port, timeout=2)
        c.request(method, path, body=body)
        r = c.getresponse(); result = (r.status, dict(r.getheaders()), r.read()); c.close()
        return result
    def raw(self, request, shutdown=False):
        with socket.create_connection(('127.0.0.1', self.port), timeout=2) as connection:
            connection.sendall(request)
            if shutdown: connection.shutdown(socket.SHUT_WR)
            result = b''
            while True:
                chunk = connection.recv(65536)
                if not chunk: break
                result += chunk
        return result
    def test_private_health_uses_loaded_fixture(self):
        status, headers, body = self.request('GET', '/health')
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)['model_version'], self.model.contract['version'])
        self.assertEqual(headers['Cache-Control'], 'no-store')
    def test_embed(self):
        status, _, body = self.request('POST', '/embed', b'fixture')
        self.assertEqual(status, 200); self.assertEqual(json.loads(body)['embedding'], [1, 0, 0])
    def test_no_face_error(self):
        status, _, body = self.request('POST', '/embed', b'no-face')
        self.assertEqual(status, 422); self.assertEqual(json.loads(body), {'code': 'NO_FACE'})
    def test_unexpected_error_sanitized(self):
        status, _, body = self.request('POST', '/embed', b'error')
        self.assertEqual(status, 503); self.assertNotIn(b'biometric', body)
    def test_unknown_path(self):
        self.assertEqual(self.request('GET', '/not-found')[0], 404)
    def test_zero_body(self):
        self.assertEqual(self.request('POST', '/embed', b'')[0], 413); self.assertEqual(self.model.calls, 0)
    def test_missing_length(self):
        self.assertIn(b' 411 ', self.raw(b'POST /embed HTTP/1.1\r\nHost: fixture\r\n\r\n'))
    def test_duplicate_content_length(self):
        self.assertIn(b' 400 ', self.raw(b'POST /embed HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\nx'))
        self.assertEqual(self.model.calls, 0)
    def test_transfer_encoding_rejected(self):
        self.assertIn(b' 400 ', self.raw(b'POST /embed HTTP/1.1\r\nTransfer-Encoding: chunked\r\nContent-Length: 1\r\n\r\nx'))
    def test_invalid_length(self):
        self.assertIn(b' 400 ', self.raw(b'POST /embed HTTP/1.1\r\nContent-Length: -1\r\n\r\n'))
    def test_oversized_body_before_read(self):
        self.assertIn(b' 413 ', self.raw(b'POST /embed HTTP/1.1\r\nContent-Length: 1500001\r\n\r\n'))
        self.assertEqual(self.model.calls, 0)
    def test_partial_body_never_infers(self):
        self.assertIn(b' 400 ', self.raw(b'POST /embed HTTP/1.1\r\nContent-Length: 10\r\n\r\nx', shutdown=True))
        self.assertEqual(self.model.calls, 0)
    def test_slow_headers_have_absolute_deadline(self):
        start = time.monotonic()
        self.raw(b'POST /embed HTTP/1.1\r\nHost: unfinished')
        self.assertLess(time.monotonic()-start, 1.5); self.assertEqual(self.model.calls, 0)
    def test_full_pool_returns_busy_without_queue(self):
        with socket.create_connection(('127.0.0.1', self.port), timeout=2) as first:
            first.sendall(b'POST /embed HTTP/1.1\r\nContent-Length: 5\r\n\r\nblock')
            self.assertTrue(self.model.started.wait(1))
            status, headers, _ = self.request('GET', '/health')
            self.assertEqual(status, 503); self.assertEqual(headers['Retry-After'], '1')
            self.model.release.set()
    def test_draining_denies_new_work(self):
        self.server.begin_drain()
        self.assertEqual(self.request('GET', '/health')[0], 503)
    def test_invalid_pool_configuration(self):
        with self.assertRaises(ValueError):
            create_server(('127.0.0.1',0), model=self.model, workers=0)


if __name__ == '__main__': unittest.main()
