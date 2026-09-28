"""Bounded private HTTP adapter. Real model validation is required before binding.

This service is intended only behind the private authenticated Worker binding,
not as an internet-facing general-purpose HTTP server. No image/request logging.
"""
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import signal
import socket
import threading
from typing import Protocol

from protocol import CaptureError, MAX_BYTES


class EmbeddingModel(Protocol):
    contract: dict
    dimensions: int
    def embed(self, data: bytes) -> dict: ...


class BoundedHTTPServer(HTTPServer):
    request_queue_size = 16
    allow_reuse_address = True

    def __init__(self, address, model: EmbeddingModel, *, workers=4, request_timeout=15.0):
        if not isinstance(workers, int) or not 1 <= workers <= 16:
            raise ValueError('workers must be 1..16')
        if not 0 < request_timeout <= 30:
            raise ValueError('request_timeout must be >0 and <=30')
        self.model = model
        self.request_timeout = float(request_timeout)
        self._slots = threading.BoundedSemaphore(workers)
        self._executor = ThreadPoolExecutor(max_workers=workers, thread_name_prefix='face-http')
        self._draining = threading.Event()
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        if self._draining.is_set() or not self._slots.acquire(blocking=False):
            try:
                request.settimeout(0.25)
                body = b'{"code":"SERVICE_BUSY"}'
                request.sendall(b'HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n'
                                b'Content-Type: application/json\r\nCache-Control: no-store\r\n'
                                b'Retry-After: 1\r\nContent-Length: ' + str(len(body)).encode() + b'\r\n\r\n' + body)
            except OSError:
                pass
            finally:
                self.shutdown_request(request)
            return
        try:
            self._executor.submit(self._serve_request, request, client_address)
        except RuntimeError:
            self._slots.release()
            self.shutdown_request(request)

    def _serve_request(self, request, client_address):
        try:
            self.finish_request(request, client_address)
        except Exception:
            # Never print a raw request, peer identity, image or model output.
            pass
        finally:
            self.shutdown_request(request)
            self._slots.release()

    def begin_drain(self):
        self._draining.set()

    def server_close(self):
        self.begin_drain()
        super().server_close()
        self._executor.shutdown(wait=True, cancel_futures=True)


class Handler(BaseHTTPRequestHandler):
    server_version = 'MobioFace'
    sys_version = ''
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_args):
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(self.server.request_timeout)
        # Absolute request budget also bounds slow headers and slow streaming bodies.
        self._deadline = threading.Timer(self.server.request_timeout, self._expire)
        self._deadline.daemon = True
        self._deadline.start()

    def _expire(self):
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

    def finish(self):
        self._deadline.cancel()
        try:
            super().finish()
        except OSError:
            pass

    def respond(self, status, value):
        self.close_connection = True  # No keep-alive/pipelined-body ambiguity.
        data = json.dumps(value, allow_nan=False, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Connection', 'close')
        self.send_header('Content-Length', str(len(data)))
        if status == 503:
            self.send_header('Retry-After', '1')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(data)

    def do_GET(self):
        if self.path != '/health':
            return self.respond(404, {'code': 'NOT_FOUND'})
        model = self.server.model
        self.respond(200, {'model_loaded': True, 'model_version': model.contract['version'],
                           'dimensions': model.dimensions})

    def do_HEAD(self):
        self.respond(405, {'code': 'METHOD_NOT_ALLOWED'})

    def do_POST(self):
        if self.path != '/embed':
            return self.respond(404, {'code': 'NOT_FOUND'})
        lengths = self.headers.get_all('Content-Length', [])
        if self.headers.get_all('Transfer-Encoding') or self.headers.get_all('Expect') or len(lengths) > 1:
            return self.respond(400, {'code': 'INVALID_FRAMING'})
        if not lengths:
            return self.respond(411, {'code': 'LENGTH_REQUIRED'})
        raw_length = lengths[0].strip()
        if not raw_length.isascii() or not raw_length.isdigit() or len(raw_length) > 10:
            return self.respond(400, {'code': 'INVALID_LENGTH'})
        size = int(raw_length)
        if not 0 < size <= MAX_BYTES:
            return self.respond(413, {'code': 'IMAGE_TOO_LARGE'})
        try:
            data = self.rfile.read(size)
            if len(data) != size:
                return self.respond(400, {'code': 'INVALID_IMAGE'})
            result = self.server.model.embed(data)
            self.respond(200, result)
        except CaptureError as error:
            allowed = {'SERVICE_BUSY', 'NO_FACE', 'MULTIPLE_FACES', 'INVALID_IMAGE', 'IMAGE_TOO_LARGE', 'POOR_CAPTURE'}
            code = error.code if error.code in allowed else 'MODEL_UNAVAILABLE'
            self.respond(503 if code in {'SERVICE_BUSY', 'MODEL_UNAVAILABLE'} else 422, {'code': code})
        except (OSError, ValueError):
            try:
                self.respond(400, {'code': 'INVALID_IMAGE'})
            except OSError:
                pass
        except Exception:
            self.respond(503, {'code': 'MODEL_UNAVAILABLE'})


def create_server(address=('0.0.0.0', 8080), *, model=None, workers=4, request_timeout=15.0):
    if model is None:
        from inference import FaceModel
        model = FaceModel()  # Hash/runtime/shape checks finish BEFORE binding.
    return BoundedHTTPServer(address, model, workers=workers, request_timeout=request_timeout)


def main():
    server = create_server()
    terminating = threading.Event()
    def terminate(_signum, _frame):
        if terminating.is_set():
            return
        terminating.set()
        server.begin_drain()
        # shutdown cannot run inside the serve_forever thread (would deadlock).
        threading.Thread(target=server.shutdown, daemon=True).start()
        # Native inference cannot safely be killed inside a Python thread.
        # Bound process shutdown if a native call fails to return during draining.
        deadline = threading.Timer(25.0, lambda: os._exit(1))
        deadline.daemon = True
        deadline.start()
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        server.serve_forever(poll_interval=0.1)
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
