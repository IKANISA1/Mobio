"""Stateless CPU embedding boundary. No gallery, raw-image storage or request logs."""
import hashlib
import io
import json
from pathlib import Path
import threading
import warnings

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

ROOT = Path(__file__).resolve().parent
from protocol import CaptureError, MAX_BYTES
MAX_PIXELS = 4_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS

class FaceModel:
    def __init__(self):
        self.contract = json.loads((ROOT / 'model-manifest.json').read_text())
        if cv2.__version__ != self.contract['opencv']:
            raise RuntimeError('OpenCV runtime mismatch')
        paths = {}
        for item in self.contract['models']:
            path = ROOT / 'models' / item['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
                raise RuntimeError('Model checksum mismatch')
            paths[item['role']] = str(path)
        cv2.setNumThreads(1)
        self.lock = threading.Lock()
        self.detector = cv2.FaceDetectorYN.create(paths['detector'], '', (320, 320), 0.9, 0.3, 5000)
        self.recognizer = cv2.FaceRecognizerSF.create(paths['recognizer'], '')
        # Actual model output, not a guessed ArcFace size. Synthetic probe proves
        # model/runtime plumbing only; it is not recognition-accuracy evidence.
        probe = np.random.default_rng(20260920).integers(0, 256, (112, 112, 3), dtype=np.uint8)
        feature = self.recognizer.feature(probe).flatten()
        self.dimensions = int(feature.size)
        self.normalize(feature)
        if self.dimensions != self.contract['dimensions']:
            raise RuntimeError('Embedding contract mismatch; use a new index')
        self.detector.setInputSize((320,320))
        self.detector.detect(np.zeros((320,320,3), dtype=np.uint8))

    def normalize(self, feature):
        values = np.asarray(feature, dtype=np.float32).flatten()
        norm = float(np.linalg.norm(values))
        if values.size != self.dimensions or not np.isfinite(values).all() or not np.isfinite(norm) or norm < 1e-8:
            raise RuntimeError('Invalid model output')
        return (values / norm).tolist()

    def decode(self, data):
        if not data or len(data) > MAX_BYTES: raise CaptureError('IMAGE_TOO_LARGE')
        try:
            with warnings.catch_warnings():
                warnings.simplefilter('error', Image.DecompressionBombWarning)
                with Image.open(io.BytesIO(data)) as source:
                    if source.format not in ('JPEG','PNG','WEBP') or getattr(source,'n_frames',1) != 1:
                        raise CaptureError('INVALID_IMAGE')
                    if source.width * source.height > MAX_PIXELS or min(source.size)<112:
                        raise CaptureError('POOR_CAPTURE')
                    upright=ImageOps.exif_transpose(source).convert('RGB')
                    upright.thumbnail((1024,1024), Image.Resampling.LANCZOS)
                    return cv2.cvtColor(np.asarray(upright), cv2.COLOR_RGB2BGR)
        except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
            raise CaptureError('INVALID_IMAGE') from None

    def embed(self, data):
        if not self.lock.acquire(blocking=False): raise CaptureError('SERVICE_BUSY')
        try:
            pixels=self.decode(data)
            self.detector.setInputSize((pixels.shape[1],pixels.shape[0]))
            _, faces=self.detector.detect(pixels)
            if faces is None or len(faces)==0: raise CaptureError('NO_FACE')
            if len(faces)!=1: raise CaptureError('MULTIPLE_FACES')
            face=faces[0]
            if not np.isfinite(face).all(): raise CaptureError('POOR_CAPTURE')
            x,y,w,h=face[:4]
            if min(w,h)<64 or x<0 or y<0 or x+w>pixels.shape[1] or y+h>pixels.shape[0]:
                raise CaptureError('POOR_CAPTURE')
            aligned=self.recognizer.alignCrop(pixels,face)
            if cv2.Laplacian(cv2.cvtColor(aligned,cv2.COLOR_BGR2GRAY),cv2.CV_64F).var()<20:
                raise CaptureError('POOR_CAPTURE')
            return {'model_version':self.contract['version'],'dimensions':self.dimensions,
                    'values':self.normalize(self.recognizer.feature(aligned))}
        finally: self.lock.release()
