"""Regenerate tests/name_vectors.json from the OCR service's normalized().

uv run --with-requirements ocr-service/requirements.txt python tools/build_name_vectors.py
Both normalisers are checked against this file: tests/test_name_vectors.py for
ocr-service/app.py and scripts/smoke/ws5a.gd for TopoCatalog.normalize. After
changing either fold, rerun this script and make both sides pass.
"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ocr_app", ROOT / "ocr-service/app.py")
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)

edge = [
    "Den Haag", "  Den   Haag  ", "'s-Hertogenbosch", "’s‑Hertogenbosch", "Neder-Rijn", "Amsterdam-Rijnkanaal",
    "Ķekava", "Łódź", "İstanbul", "Straße", "Ørsted", "Curaçao", "Åland", "Egeïsche Zee", "Rhône", "Kraków",
    "ZÜRICH", "SÃO PAULO", "Ǆ", "a\tb\u00a0c\u2003d\u3000e\n f", "Utrecht (provincie)", "St. Petersburg", "", "   ",
]
# Latin letters and punctuation that NFKD changes, 32 characters per case.
blocks = [(0xA0, 0x24F), (0x2010, 0x206F), (0x1E00, 0x1EFF)]
sweeps = []
for first, last in blocks:
    for start in range(first, last + 1, 32):
        sweeps.append(" ".join(chr(cp) for cp in range(start, min(start + 32, last + 1) + 0)))
cases = [[text, app.normalized(text)] for text in edge + sweeps]
out = {"note": "Input and expected normalised text from ocr-service/app.py normalized(); regenerate with tools/build_name_vectors.py.", "cases": cases}
(ROOT / "tests/name_vectors.json").write_text(json.dumps(out, ensure_ascii=False, indent=0) + "\n")
print("Wrote", len(cases), "cases")
