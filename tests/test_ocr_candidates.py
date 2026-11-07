"""Run after installing ocr-service requirements: python -m unittest discover -s tests."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("ocr_app", Path(__file__).resolve().parents[1] / "ocr-service/app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CandidateTests(unittest.TestCase):
    def test_whole_names_and_accents(self):
        found = module.candidates("1. Arnhem\n2. België\n3. Parijs")
        self.assertIn("Arnhem", found)
        self.assertIn("België", found)
        self.assertIn("Parijs", found)

    def test_no_substrings_or_hallucinated_places(self):
        self.assertNotIn("Rome", module.candidates("romero"))
        self.assertEqual(module.candidates("Onbekenddorp"), [])

    def test_aliases(self):
        self.assertIn("Den Bosch", module.candidates("'s-Hertogenbosch"))

if __name__ == '__main__':
    unittest.main()
