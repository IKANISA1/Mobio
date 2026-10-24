"""Private proposal: format admission occurs before any denied parser.

No adversarial decoder payload is loaded and no face model is constructed.
Run only after root reviews and activates the coherent candidate.
"""
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PIL import Image
from inference import CaptureError, FaceModel


class DecodeFormatAdmissionTest(unittest.TestCase):
    def setUp(self):
        # decode does not access constructor/model state.
        self.model = FaceModel.__new__(FaceModel)
        Image.init()

    def test_denied_registered_parsers_are_never_invoked(self):
        for format_name, prefix in (("PSD", b"8BPS"), ("TIFF", b"II*\x00"), ("BMP", b"BM")):
            with self.subTest(format=format_name):
                opener = Mock(side_effect=AssertionError("Denied decoder was invoked"))
                accept = lambda data, expected=prefix: data.startswith(expected)
                with patch.dict(Image.OPEN, {format_name: (opener, accept)}):
                    with self.assertRaises(CaptureError) as result:
                        self.model.decode(prefix + bytes(64))
                    self.assertEqual(result.exception.code, "INVALID_IMAGE")
                    opener.assert_not_called()

    def test_supported_formats_keep_rgb_bgr_dimensions(self):
        for format_name in ("JPEG", "PNG", "WEBP"):
            with self.subTest(format=format_name):
                data = io.BytesIO()
                Image.new("RGB", (480, 320), (30, 80, 140)).save(data, format=format_name)
                pixels = self.model.decode(data.getvalue())
                self.assertEqual(pixels.shape, (320, 480, 3))
                self.assertEqual(str(pixels.dtype), "uint8")

    def test_jpeg_exif_orientation_is_preserved(self):
        data = io.BytesIO()
        image = Image.new("RGB", (600, 300))
        exif = Image.Exif()
        exif[274] = 6
        image.save(data, format="JPEG", exif=exif)
        self.assertEqual(self.model.decode(data.getvalue()).shape, (600, 300, 3))

    def test_animation_still_rejected(self):
        data = io.BytesIO()
        first = Image.new("RGB", (320, 320), "red")
        second = Image.new("RGB", (320, 320), "blue")
        first.save(data, format="PNG", save_all=True, append_images=[second], duration=10, loop=0)
        with self.assertRaises(CaptureError) as result:
            self.model.decode(data.getvalue())
        self.assertEqual(result.exception.code, "INVALID_IMAGE")


if __name__ == "__main__":
    unittest.main()
