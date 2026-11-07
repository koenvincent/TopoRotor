import asyncio
import importlib.util
import io
import os
import subprocess
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
            return {"api_version":api.API_VERSION,"catalog_version":api.CATALOG_VERSION,"candidates": [], "text": "", "review_required": True}

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
