"""Authenticated, bounded OCR endpoint. Worksheet bytes never persist to disk."""
import asyncio
import hashlib
import io
import json
import logging
import os
import re
import secrets
import shutil
import subprocess
import time
import unicodedata
import warnings
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

app = FastAPI(title="TopoRotor OCR", version="0.3.0")
# uvicorn configures this logger (handler + INFO level); never log image bytes or OCR text.
log = logging.getLogger("uvicorn.error")
API_VERSION = 1
CATALOG_BYTES = (Path(__file__).resolve().parents[1] / "data" / "places.json").read_bytes()
CATALOG = json.loads(CATALOG_BYTES.decode("utf-8"))
# Clients compare this with the sha256 of their bundled places.json (first 16 hex chars).
CATALOG_VERSION = hashlib.sha256(CATALOG_BYTES).hexdigest()[:16]
MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 12_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS
# Includes uploads and decoding, so multiple slow uploads cannot exhaust image RAM.
OCR_SLOTS = asyncio.Semaphore(2)


class ExtractResponse(BaseModel):
    api_version: int
    catalog_version: str
    text: str
    candidates: list[str]
    review_required: bool


class ErrorBody(BaseModel):
    detail: str


_IMAGE_SCHEMA = {"schema": {"type": "string", "format": "binary"}}
_EXTRACT_ERRORS = {code: {"model": ErrorBody} for code in (400, 401, 408, 413, 415, 429, 502, 503, 504)}


def normalized(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.casefold())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", re.sub(r"['\u2018\u2019`]", "", text.replace("-", " "))).strip()


def candidates(text: str) -> list[str]:
    text = normalized(text)
    matches = []
    for p in CATALOG:
        for alias in [p["name"], *p.get("aliases", [])]:
            if re.search(r"(?<!\w)" + re.escape(normalized(alias)) + r"(?!\w)", text):
                matches.append(p["name"])
                break
    return matches


def _detect_tesseract_langs() -> set[str] | None:
    """Checked once at startup; None when the tesseract binary is missing or unusable."""
    if shutil.which("tesseract") is None:
        return None
    try:
        result = subprocess.run(["tesseract", "--list-langs"], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    output = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    return {line.strip() for line in output.splitlines()[1:] if line.strip()}


TESSERACT_LANGS = _detect_tesseract_langs()


def configured_tokens() -> list[str] | None:
    """All accepted tokens (TOPOROTOR_OCR_TOKENS comma list plus TOPOROTOR_OCR_TOKEN).

    Returns None when no token is set or any token is shorter than 32 bytes.
    """
    raw = os.environ.get("TOPOROTOR_OCR_TOKENS", "")
    tokens = [t.strip() for t in raw.split(",") if t.strip()]
    single = os.environ.get("TOPOROTOR_OCR_TOKEN", "")
    if single:
        tokens.append(single)
    if not tokens or any(len(t.encode("utf-8")) < 32 for t in tokens):
        return None
    return tokens


def readiness_problems() -> list[str]:
    problems = []
    if configured_tokens() is None:
        problems.append("token_not_configured")
    if TESSERACT_LANGS is None:
        problems.append("tesseract_not_found")
    elif not {"nld", "eng"} <= TESSERACT_LANGS:
        problems.append("tesseract_langs_missing")
    return problems


for _problem in readiness_problems():
    log.warning("ocr_not_ready reason=%s", _problem)


def authorize(request: Request) -> None:
    tokens = configured_tokens()
    if tokens is None:
        raise HTTPException(503, "OCR authentication is not configured")
    supplied = request.headers.get("authorization", "").encode("utf-8")
    matched = None
    # Compare against every token so timing does not reveal which one matched.
    for index, token in enumerate(tokens):
        if secrets.compare_digest(supplied, ("Bearer " + token).encode("utf-8")) and matched is None:
            matched = index
    if matched is None:
        raise HTTPException(401, "Invalid OCR token", headers={"WWW-Authenticate": "Bearer"})
    # Log only the index, never the token, to help trace and revoke a leaked credential.
    log.info("ocr_auth token_index=%d", matched)


def recognize(content: bytes) -> dict:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            # Restrict plugins at open time so only PNG/JPEG header parsers see untrusted bytes.
            with Image.open(io.BytesIO(content), formats=["PNG", "JPEG"]) as source:
                log.info("ocr_image pixels=%d", source.width * source.height)
                # Validate dimensions before exif_transpose/load decode image pixels.
                if source.width * source.height > MAX_PIXELS:
                    log.warning("ocr_rejected status=413 width=%d height=%d", source.width, source.height)
                    raise HTTPException(413, "Image dimensions too large")
                if source.format not in {"PNG", "JPEG"}:
                    raise HTTPException(415, "Use PNG or JPEG")
                image = ImageOps.exif_transpose(source)
                image.thumbnail((1800, 1800))
                image = ImageOps.grayscale(image)
                encoded = io.BytesIO()
                image.save(encoded, format="PNG")
                # Piping pixels avoids pytesseract's temporary worksheet file on disk.
                ocr_started = time.monotonic()
                result = subprocess.run(
                    ["tesseract", "stdin", "stdout", "-l", "nld+eng", "--psm", "11"],
                    input=encoded.getvalue(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    timeout=30, check=True,
                )
                log.info("ocr_engine duration_ms=%d", (time.monotonic() - ocr_started) * 1000)
                text = result.stdout.decode("utf-8", errors="replace")
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(413, "Image dimensions too large")
    except FileNotFoundError:
        log.error("ocr_failed status=503 reason=tesseract_not_found")
        raise HTTPException(503, "OCR engine is not installed")
    except subprocess.CalledProcessError as e:
        log.warning("ocr_failed status=502 rc=%s", e.returncode)
        raise HTTPException(502, "OCR engine failed")
    except (UnidentifiedImageError, OSError, ValueError) as e:
        log.warning("ocr_failed status=400 error=%s", type(e).__name__)
        raise HTTPException(400, "Invalid image")
    except subprocess.TimeoutExpired:
        log.warning("ocr_failed status=504 reason=tesseract_timeout")
        raise HTTPException(504, "OCR timed out")
    return {"api_version": API_VERSION, "catalog_version": CATALOG_VERSION,
            "text": text, "candidates": candidates(text), "review_required": True}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    problems = readiness_problems()
    if problems:
        raise HTTPException(503, {"status": "not_ready", "reasons": problems})
    return {"status": "ready"}


@app.post(
    "/extract",
    response_model=ExtractResponse,
    responses=_EXTRACT_ERRORS,
    openapi_extra={"requestBody": {"required": True, "content": {
        "image/png": _IMAGE_SCHEMA, "image/jpeg": _IMAGE_SCHEMA}}},
)
async def extract(request: Request):
    started = time.monotonic()
    try:
        result = await _extract(request)
    except HTTPException as e:
        log.warning("ocr_request status=%s reason=%r duration_ms=%d",
                    e.status_code, e.detail, (time.monotonic() - started) * 1000)
        raise
    log.info("ocr_request status=200 candidates=%d duration_ms=%d",
             len(result["candidates"]), (time.monotonic() - started) * 1000)
    return result


async def _extract(request: Request):
    authorize(request)
    content_type = request.headers.get("content-type", "").split(";", 1)[0].lower()
    if content_type not in {"image/png", "image/jpeg"}:
        raise HTTPException(415, "Use PNG or JPEG")
    if OCR_SLOTS.locked():
        raise HTTPException(429, "OCR is busy; retry later", headers={"Retry-After": "5"})
    await OCR_SLOTS.acquire()
    try:
        content = bytearray()
        try:
            async with asyncio.timeout(20):
                async for chunk in request.stream():
                    if len(content) + len(chunk) > MAX_BYTES:
                        raise HTTPException(413, "Image too large")
                    content.extend(chunk)
        except TimeoutError:
            raise HTTPException(408, "Upload timed out")
        log.info("ocr_upload bytes=%d", len(content))
        # Time budget: upload 20 s + decode + Tesseract 30 s; the app's HTTPRequest timeout (60 s) must stay above it.
        if await request.is_disconnected():
            raise HTTPException(408, "Client disconnected")
        # Decoding + Tesseract must not block FastAPI's event loop.
        return await run_in_threadpool(recognize, bytes(content))
    finally:
        OCR_SLOTS.release()
