"""Executes the same HTTP handler and real models used in the image."""
import io
import json
import os
from pathlib import Path
import sys
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


class HttpSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.url = os.environ.get('FACE_SMOKE_BASE_URL', '').rstrip('/')
        if cls.url:
            cls.server = None
            return
        from server import Handler
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        if cls.server is None:
            return
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_health_requires_real_loaded_model(self):
        with urllib.request.urlopen(self.url + "/health", timeout=2) as response:
            body = json.load(response)
        self.assertTrue(body["model_loaded"])
        self.assertEqual(body["dimensions"], 128)
        self.assertEqual(body["model_version"], "yunet2023mar-sface2021dec-opencv4.11-v1")

    def test_real_detection_returns_structured_no_face(self):
        stream = io.BytesIO()
        Image.new("RGB", (320, 320)).save(stream, "JPEG")
        request = urllib.request.Request(self.url + "/embed", data=stream.getvalue())
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request, timeout=3)
        with error.exception as response:
            self.assertEqual(response.code, 422)
            self.assertEqual(json.load(response), {"code": "NO_FACE"})

    def test_arbitrary_image_url_is_not_fetched(self):
        request = urllib.request.Request(self.url + "/embed", data=b'{"url":"https://example.invalid/image"}')
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request, timeout=3)
        with error.exception as response:
            self.assertEqual(json.load(response), {"code": "INVALID_IMAGE"})
