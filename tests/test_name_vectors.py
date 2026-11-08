"""Run after installing ocr-service requirements: python -m unittest discover -s tests.

The game folds names with TopoCatalog.normalize (GDScript); scripts/smoke/ws5a.gd
checks it against the same tests/name_vectors.json.
"""
import importlib.util
import json
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ocr_app_vectors", ROOT / "ocr-service/app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NameVectorTests(unittest.TestCase):
    def test_vectors(self):
        cases = json.loads((ROOT / "tests/name_vectors.json").read_text(encoding="utf-8"))["cases"]
        self.assertGreater(len(cases), 40)
        for text, expected in cases:
            self.assertEqual(module.normalized(text), expected, repr(text))

    def test_catalogue_keys_are_plain_ascii(self):
        # The same invariant is asserted for the GDScript fold, so a new place
        # with a letter neither side folds is caught on both.
        for place in json.loads((ROOT / "data/places.json").read_text(encoding="utf-8")):
            for name in [place["name"], *place["aliases"]]:
                self.assertTrue(re.fullmatch(r"[ -~]+", module.normalized(name)), name)


if __name__ == "__main__":
    unittest.main()
