import asyncio
import importlib.util
import io
import os
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient
from PIL import Image

spec = importlib.util.spec_from_file_location("ocr_api_under_test", Path(__file__).resolve().parents[1] / "ocr-service/app.py")
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)
TOKEN = "unit-test-token-" * 4
HEADERS = {"Authorization": "Bearer " + TOKEN, "Content-Type": "image/png"}


def png(width=12, height=12):
    content = io.BytesIO()
    Image.new("RGB", (width, height), "white").save(content, format="PNG")
    return content.getvalue()


class OCRAPITests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": TOKEN,"TOPOROTOR_OCR_TOKENS":""})
        self.env.start()
        api.OCR_SLOTS = asyncio.Semaphore(2)
        self.client = TestClient(api.app)

    def tearDown(self):
        self.client.close()
        self.env.stop()

    def test_readiness_checks_token_engine_and_languages(self):
        with patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}):
            self.assertEqual(self.client.get("/ready").status_code, 200)
            with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": ""}):
                self.assertEqual(self.client.get("/ready").status_code, 503)
        for languages in [None, {"eng"}]:
            with self.subTest(languages=languages), patch.object(api, "TESSERACT_LANGS", languages):
                self.assertEqual(self.client.get("/ready").status_code, 503)
                self.assertEqual(self.client.get("/health").status_code, 200)

    def test_multiple_tokens_can_be_revoked_independently(self):
        second = "second-device-token-" * 3
        output = subprocess.CompletedProcess([], 0, b"Arnhem", b"")
        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": "", "TOPOROTOR_OCR_TOKENS": TOKEN + "," + second}), patch.object(api.subprocess, "run", return_value=output):
            for token in [TOKEN, second]:
                response = self.client.post("/extract", headers={**HEADERS, "Authorization": "Bearer " + token}, content=png())
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["api_version"], 1)
                self.assertEqual(response.json()["catalog_version"], api.CATALOG_VERSION)
            with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKENS": second}):
                self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 401)
                self.assertEqual(self.client.post("/extract", headers={**HEADERS, "Authorization": "Bearer " + second}, content=png()).status_code, 200)

    def test_short_token_entry_is_skipped_and_reported_by_index(self):
        short = "too-short"
        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": "", "TOPOROTOR_OCR_TOKENS": TOKEN + "," + short}), \
                patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}), \
                patch.object(api.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"Arnhem", b"")):
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 200)
            bad = {**HEADERS, "Authorization": "Bearer " + short}
            self.assertEqual(self.client.post("/extract", headers=bad, content=png()).status_code, 401)
            ready = self.client.get("/ready")
            self.assertEqual(ready.status_code, 200)
            self.assertEqual(ready.json()["warnings"], ["token_too_short index=1"])
            self.assertNotIn(short, ready.text)

    def test_all_tokens_short_reports_the_real_reason(self):
        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": "", "TOPOROTOR_OCR_TOKENS": "aaa,bbb"}), \
                patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}):
            ready = self.client.get("/ready")
            self.assertEqual(ready.status_code, 503)
            self.assertEqual(ready.json()["reasons"], ["token_too_short index=0", "token_too_short index=1"])
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 503)

    def test_ready_has_the_same_top_level_shape_and_string_detail(self):
        with patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}):
            ok = self.client.get("/ready").json()
        with patch.object(api, "TESSERACT_LANGS", None):
            response = self.client.get("/ready")
        self.assertEqual(ok["status"], "ready")
        self.assertEqual(response.status_code, 503)
        body = response.json()
        self.assertEqual(body["status"], "not_ready")
        self.assertEqual(body["reasons"], ["tesseract_not_found"])
        self.assertIsInstance(body["detail"], str)

    def test_missing_catalog_is_reported_by_ready_not_by_import_crash(self):
        raw, places, problem = api.load_catalog(Path("/nonexistent/places.json"))
        self.assertEqual((raw, places, problem), (b"", [], "catalog_missing"))
        with patch.object(api, "CATALOG_PROBLEM", "catalog_missing"), patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}):
            self.assertIn("catalog_missing", self.client.get("/ready").json()["reasons"])
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 503)

    def test_catalog_path_can_be_configured(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "places.json"
            path.write_text("[not json", encoding="utf-8")
            self.assertEqual(api.load_catalog(path)[2], "catalog_invalid")
            path.write_text('[{"name": "Arnhem"}]', encoding="utf-8")
            self.assertIsNone(api.load_catalog(path)[2])

    def test_slot_count_is_configurable(self):
        for value, expected in [("", 2), ("5", 5), ("0", 1), ("many", 2)]:
            with self.subTest(value=value), patch.dict(os.environ, {"TOPOROTOR_OCR_SLOTS": value}):
                self.assertEqual(api.configured_slots(), expected)

    def test_one_token_cannot_take_every_slot(self):
        self.assertEqual(api.per_token_limit(1), 2)
        self.assertEqual(api.per_token_limit(2), 1)
        with patch.dict(os.environ, {"TOPOROTOR_OCR_SLOTS": "1"}):
            self.assertEqual(api.per_token_limit(2), 1)
        second = "second-device-token-" * 3
        api.IN_FLIGHT.clear()
        api.IN_FLIGHT[0] = 1
        output = subprocess.CompletedProcess([], 0, b"Arnhem", b"")
        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": "", "TOPOROTOR_OCR_TOKENS": TOKEN + "," + second}), patch.object(api.subprocess, "run", return_value=output):
            # Token 0 already holds its share: busy, while token 1 still gets the free slot.
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 429)
            self.assertEqual(self.client.post("/extract", headers={**HEADERS, "Authorization": "Bearer " + second}, content=png()).status_code, 200)
        self.assertEqual(api.IN_FLIGHT[0], 1)
        self.assertEqual(api.IN_FLIGHT[1], 0)
        api.IN_FLIGHT.clear()

    def test_missing_configuration_fails_closed(self):
        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": ""}):
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 503)

    def test_unauthenticated_upload_does_not_start_ocr(self):
        with patch.object(api.subprocess, "run") as run:
            response = self.client.post("/extract", headers={"Content-Type": "image/png"}, content=png())
            self.assertEqual(response.status_code, 401)
            run.assert_not_called()

    def test_rejects_byte_limit_and_releases_slot(self):
        with patch.object(api, "MAX_BYTES", 16):
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 413)
        self.assertEqual(api.OCR_SLOTS._value, 2)

    def test_rejects_pixels_before_decoding(self):
        with patch.object(api, "MAX_PIXELS", 100), patch.object(api.ImageOps, "exif_transpose") as decode:
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 413)
            decode.assert_not_called()

    def test_engine_failure_does_not_log_worksheet_content(self):
        failure = subprocess.CalledProcessError(1, "tesseract", stderr=b"private worksheet text")
        with patch.object(api.subprocess, "run", side_effect=failure), self.assertLogs(api.log, level="WARNING") as logs:
            response = self.client.post("/extract", headers=HEADERS, content=png())
        self.assertEqual(response.status_code, 502)
        self.assertNotIn("private worksheet text", "\n".join(logs.output))

    def test_corrupt_image(self):
        self.assertEqual(self.client.post("/extract", headers=HEADERS, content=b"invalid image").status_code, 400)

    def test_content_type_rejected(self):
        self.assertEqual(self.client.post("/extract", headers={**HEADERS, "Content-Type": "application/octet-stream"}, content=png()).status_code, 415)

    def test_success_uses_stdin_and_returns_reviewable_candidates(self):
        with patch.object(api.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"Arnhem en Parijs", b"")) as run:
            response = self.client.post("/extract", headers=HEADERS, content=png())
            self.assertEqual(response.status_code, 200)
            self.assertEqual(set(response.json()["candidates"]), {"Arnhem", "Parijs"})
            self.assertTrue(response.json()["review_required"])
            self.assertEqual(run.call_args.args[0][:3], ["tesseract", "stdin", "stdout"])
            self.assertTrue(run.call_args.kwargs["input"].startswith(b"\x89PNG"))
            self.assertTrue(run.call_args.kwargs["check"])

    def test_response_adds_regions_without_changing_candidates(self):
        with patch.object(api.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"Noordzee\nRhein\nArnhem", b"")):
            body = self.client.post("/extract", headers=HEADERS, content=png()).json()
        self.assertEqual(body["candidates"], ["Arnhem", "Noordzee", "Rijn"])
        self.assertEqual([p["name"] for p in body["candidate_places"]], body["candidates"])
        regions = {p["name"]: p["regions"] for p in body["candidate_places"]}
        self.assertEqual(regions["Noordzee"], ["nl", "eu"])
        self.assertEqual(regions["Rijn"], ["eu"])
        self.assertEqual(regions["Arnhem"], ["nl"])

    def test_engine_start_failure_is_a_server_error_not_invalid_image(self):
        for error in [PermissionError(13, "denied"), BrokenPipeError()]:
            with self.subTest(error=type(error).__name__), patch.object(api.subprocess, "run", side_effect=error):
                self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 503)

    def test_engine_failure_logs_a_fixed_reason_and_refreshes_languages(self):
        failure = subprocess.CalledProcessError(1, "tesseract", stderr=b"Error opening data file /x/nld.traineddata\nprivate worksheet text")
        with patch.object(api.subprocess, "run", side_effect=failure), patch.object(api, "TESSERACT_LANGS", {"nld", "eng"}), \
                patch.object(api, "_detect_tesseract_langs", return_value={"eng"}), self.assertLogs(api.log, level="WARNING") as logs:
            self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, 502)
            self.assertEqual(api.TESSERACT_LANGS, {"eng"})
            self.assertEqual(self.client.get("/ready").json()["reasons"], ["tesseract_langs_missing"])
        output = "\n".join(logs.output)
        self.assertIn("reason=language_data", output)
        self.assertNotIn("private worksheet text", output)
        self.assertEqual(api.tesseract_failure_reason(None), "unknown")

    def test_missing_engine_and_timeout_are_distinct(self):
        for error, code in [(FileNotFoundError(), 503), (subprocess.TimeoutExpired("tesseract", 30), 504), (subprocess.CalledProcessError(1, "tesseract"), 502)]:
            with self.subTest(code=code), patch.object(api.subprocess, "run", side_effect=error):
                self.assertEqual(self.client.post("/extract", headers=HEADERS, content=png()).status_code, code)


class OCRConcurrencyTests(unittest.IsolatedAsyncioTestCase):
    async def test_slow_ocr_keeps_health_responsive_and_caps_parallel_uploads(self):
        started = threading.Event()
        release = threading.Event()
        api.OCR_SLOTS = asyncio.Semaphore(2)
        active = 0
        active_lock = threading.Lock()

        def slow_recognize(_):
            nonlocal active
            with active_lock:
                active += 1
                if active == 2:
                    started.set()
            release.wait(2)
            return {"api_version":api.API_VERSION,"catalog_version":api.CATALOG_VERSION,"candidates": [], "candidate_places": [], "text": "", "review_required": True}

        with patch.dict(os.environ, {"TOPOROTOR_OCR_TOKEN": TOKEN,"TOPOROTOR_OCR_TOKENS":""}), patch.object(api, "recognize", side_effect=slow_recognize):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=api.app), base_url="http://test") as client:
                begin = time.monotonic()
                requests = [asyncio.create_task(client.post("/extract", headers=HEADERS, content=png())) for _ in range(2)]
                try:
                    self.assertTrue(await asyncio.to_thread(started.wait, 1))
                    health = await client.get("/health")
                    busy = await client.post("/extract", headers=HEADERS, content=png())
                    self.assertEqual(health.status_code, 200)
                    self.assertEqual(busy.status_code, 429)
                    self.assertLess(time.monotonic() - begin, 1.5)
                finally:
                    release.set()
                    responses = await asyncio.gather(*requests)
                self.assertTrue(all(r.status_code == 200 for r in responses))
                self.assertEqual(api.OCR_SLOTS._value, 2)


if __name__ == "__main__":
    unittest.main()
