import importlib.util
import os
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("ocr_integration", Path(__file__).resolve().parents[1] / "ocr-service/app.py")
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


@unittest.skipUnless(os.environ.get("TOPOROTOR_TEST_REAL_OCR") == "1", "Set TOPOROTOR_TEST_REAL_OCR=1 with Dutch + English Tesseract installed")
class RealOCRTests(unittest.TestCase):
    def test_actual_worksheet_recognition(self):
        worksheet = Path(__file__).resolve().parents[1] / "examples/demo-werkblad.png"
        result = api.recognize(worksheet.read_bytes())
        expected = {"Amsterdam", "Rotterdam", "Den Haag", "Utrecht", "Arnhem", "Zwolle", "Groningen", "Leeuwarden"}
        self.assertTrue(expected.issubset(set(result["candidates"])))
        self.assertTrue(result["review_required"])
