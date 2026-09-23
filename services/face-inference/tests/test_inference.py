import io,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
from PIL import Image
from inference import FaceModel,CaptureError
class ModelSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.model=FaceModel()
    def test_actual_runtime_dimension_and_blank_detection(self):
        self.assertEqual(self.model.dimensions,128)
        data=io.BytesIO();Image.new('RGB',(320,320)).save(data,format='JPEG')
        with self.assertRaises(CaptureError) as result:self.model.embed(data.getvalue())
        self.assertEqual(result.exception.code,'NO_FACE')
    def test_output_finite_and_normalized(self):
        feature=self.model.recognizer.feature(np.random.default_rng(1).integers(0,256,(112,112,3),dtype=np.uint8))
        values=self.model.normalize(feature);self.assertAlmostEqual(np.linalg.norm(values),1,places=5)
        for bad in [np.zeros(128),np.ones(127),np.full(128,np.nan)]:
            with self.assertRaises(RuntimeError):self.model.normalize(bad)
    def test_upload_and_decoded_pixel_limits(self):
        for data in [b'invalid',b'x'*1500001]:
            with self.assertRaises(CaptureError):self.model.decode(data)
        data=io.BytesIO();Image.new('RGB',(3000,2000)).save(data,format='PNG')
        with self.assertRaises(CaptureError):self.model.decode(data.getvalue())
    def test_exif_orientation_and_size(self):
        data=io.BytesIO();image=Image.new('RGB',(600,300));exif=Image.Exif();exif[274]=6;image.save(data,format='JPEG',exif=exif)
        self.assertEqual(self.model.decode(data.getvalue()).shape,(600,300,3))
    def test_busy_is_bounded(self):
        self.model.lock.acquire()
        try:
            with self.assertRaises(CaptureError) as result:self.model.embed(b'x')
            self.assertEqual(result.exception.code,'SERVICE_BUSY')
        finally:self.model.lock.release()
if __name__=='__main__':unittest.main()
