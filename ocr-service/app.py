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
from fastapi.responses import JSONResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

app = FastAPI(title="TopoRotor OCR", version="0.4.0")
# uvicorn configures this logger (handler + INFO level); never log image bytes or OCR text.
log = logging.getLogger("uvicorn.error")
API_VERSION = 1
# The catalogue defaults to the repository layout; set TOPOROTOR_CATALOG_PATH to deploy without it.
CATALOG_PATH = Path(os.environ.get("TOPOROTOR_CATALOG_PATH") or Path(__file__).resolve().parents[1] / "data" / "places.json")


def load_catalog(path: Path) -> tuple[bytes, list, str | None]:
    """Returns (raw bytes, places, problem). A bad catalogue is reported by /ready, not by a crash at import."""
    try:
        raw = path.read_bytes()
    except OSError:
        return b"", [], "catalog_missing"
    try:
        places = json.loads(raw.decode("utf-8"))
    except ValueError:
        return b"", [], "catalog_invalid"
    if not isinstance(places, list) or not all(isinstance(p, dict) and isinstance(p.get("name"), str) for p in places):
        return b"", [], "catalog_invalid"
    return raw, places, None


CATALOG_BYTES, CATALOG, CATALOG_PROBLEM = load_catalog(CATALOG_PATH)
# Clients compare this with the sha256 of their bundled places.json (first 16 hex chars).
CATALOG_VERSION = hashlib.sha256(CATALOG_BYTES).hexdigest()[:16] if CATALOG_PROBLEM is None else ""
MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 12_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS


def configured_slots() -> int:
    """TOPOROTOR_OCR_SLOTS (default 2) applies per uvicorn worker process, so total = workers x slots."""
    raw = os.environ.get("TOPOROTOR_OCR_SLOTS", "")
    try:
        return max(1, int(raw)) if raw.strip() else 2
    except ValueError:
        logging.getLogger("uvicorn.error").warning("ocr_config_warning reason=slots_not_an_integer using=2")
        return 2


# Includes uploads and decoding, so multiple slow uploads cannot exhaust image RAM.
OCR_SLOTS = asyncio.Semaphore(configured_slots())
# Requests in flight per token index, so one token cannot occupy every slot.
IN_FLIGHT: dict[int, int] = {}


class CandidatePlace(BaseModel):
    name: str
    # Catalogue regions ("nl", "eu") that matched; a name such as Noordzee can exist in both.
    regions: list[str]


class ExtractResponse(BaseModel):
    api_version: int
    catalog_version: str
    text: str
    candidates: list[str]
    # Same order and length as candidates; added without changing candidates.
    candidate_places: list[CandidatePlace]
    review_required: bool


class ErrorBody(BaseModel):
    detail: str


class ReadyBody(BaseModel):
    status: str
    reasons: list[str] = []
    warnings: list[str] = []
    detail: str | None = None


_IMAGE_SCHEMA = {"schema": {"type": "string", "format": "binary"}}
_EXTRACT_ERRORS = {code: {"model": ErrorBody} for code in (400, 401, 408, 413, 415, 429, 502, 503, 504)}


def normalized(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.casefold())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", re.sub(r"['\u2018\u2019`]", "", text.replace("-", " "))).strip()


def _build_alias_index(places: list) -> list[tuple[re.Pattern, list[int]]]:
    """Patterns for every normalized name/alias, longest first, each with the catalogue entries it names."""
    by_alias: dict[str, list[int]] = {}
    for i, p in enumerate(places):
        for alias in [p["name"], *p.get("aliases", [])]:
            key = normalized(alias)
            if key and i not in by_alias.setdefault(key, []):
                by_alias[key].append(i)
    return [(re.compile(r"(?<!\w)" + re.escape(key) + r"(?!\w)"), by_alias[key])
            for key in sorted(by_alias, key=len, reverse=True)]


ALIAS_INDEX = _build_alias_index(CATALOG)


def match_places(text: str) -> list[dict]:
    """Catalogue places named in text, in catalogue order, one entry per name with its matching regions.

    Longest names claim their text first and are masked, so the parts of a longer name
    (Rijn in Neder-Rijn, Limburg in Zuid-Limburg) cannot match as places of their own.
    """
    text = normalized(text)
    hits: set[int] = set()
    for pattern, entries in ALIAS_INDEX:
        # NUL is neither a word character nor whitespace, so a masked span also blocks multi-word matches across it.
        text, count = pattern.subn(lambda m: "\0" * len(m.group()), text)
        if count:
            hits.update(entries)
    found: dict[str, list[str]] = {}
    for i in sorted(hits):
        regions = found.setdefault(CATALOG[i]["name"], [])
        region = CATALOG[i].get("region", "")
        if region and region not in regions:
            regions.append(region)
    return [{"name": name, "regions": regions} for name, regions in found.items()]


def candidates(text: str) -> list[str]:
    return [m["name"] for m in match_places(text)]


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


def token_state() -> tuple[list[tuple[int, str]], list[int]]:
    """Splits the configured tokens into usable (index, token) pairs and the indexes of rejected ones (shorter than 32 bytes).

    Index = position in TOPOROTOR_OCR_TOKENS (empty entries skipped); TOPOROTOR_OCR_TOKEN comes last.
    """
    raw = os.environ.get("TOPOROTOR_OCR_TOKENS", "")
    entries = [t.strip() for t in raw.split(",") if t.strip()]
    single = os.environ.get("TOPOROTOR_OCR_TOKEN", "")
    if single:
        entries.append(single)
    valid = [(i, t) for i, t in enumerate(entries) if len(t.encode("utf-8")) >= 32]
    rejected = [i for i, t in enumerate(entries) if len(t.encode("utf-8")) < 32]
    return valid, rejected


def configured_tokens() -> list[str] | None:
    """All accepted tokens (TOPOROTOR_OCR_TOKENS comma list plus TOPOROTOR_OCR_TOKEN).

    Entries shorter than 32 bytes are skipped (reported by readiness), so one bad entry
    cannot lock out clients holding a valid token. None when no usable token remains.
    """
    return [t for _, t in token_state()[0]] or None


def readiness_problems() -> list[str]:
    problems = []
    valid, rejected = token_state()
    if not valid:
        problems += [f"token_too_short index={i}" for i in rejected] or ["token_not_configured"]
    if CATALOG_PROBLEM:
        problems.append(CATALOG_PROBLEM)
    if TESSERACT_LANGS is None:
        problems.append("tesseract_not_found")
    elif not {"nld", "eng"} <= TESSERACT_LANGS:
        problems.append("tesseract_langs_missing")
    return problems


def readiness_warnings() -> list[str]:
    """Problems that do not stop the service: rejected token entries while other tokens still work."""
    valid, rejected = token_state()
    return [f"token_too_short index={i}" for i in rejected] if valid else []


for _problem in readiness_problems():
    log.warning("ocr_not_ready reason=%s", _problem)
for _warning in readiness_warnings():
    log.warning("ocr_config_warning reason=%s ignored", _warning)


def authorize(request: Request) -> tuple[int, int]:
    """Returns (matched token index, number of distinct tokens)."""
    tokens = token_state()[0]
    if not tokens:
        raise HTTPException(503, "OCR authentication is not configured")
    supplied = request.headers.get("authorization", "").encode("utf-8")
    matched = None
    # Compare against every token so timing does not reveal which one matched.
    for index, token in tokens:
        if secrets.compare_digest(supplied, ("Bearer " + token).encode("utf-8")) and matched is None:
            matched = index
    if matched is None:
        raise HTTPException(401, "Invalid OCR token", headers={"WWW-Authenticate": "Bearer"})
    # Log only the index, never the token, to help trace and revoke a leaked credential.
    log.info("ocr_auth token_index=%d", matched)
    return matched, len({t for _, t in tokens})


# Tesseract stderr holds engine diagnostics, but is never logged verbatim: only these fixed labels.
_TESSERACT_FAILURES = [
    ("language_data", re.compile(rb"Error opening data file|Failed loading language|Could not initialize tesseract|traineddata")),
    ("input_image", re.compile(rb"Image too small|Cannot open input file|Error during processing")),
    ("resources", re.compile(rb"[Oo]ut of memory|bad_alloc|Cannot allocate")),
]


def tesseract_failure_reason(stderr: bytes | None) -> str:
    for label, pattern in _TESSERACT_FAILURES:
        if stderr and pattern.search(stderr):
            return label
    return "unknown"


def prepare_image(content: bytes) -> bytes:
    """Decodes the upload and returns grayscale PNG bytes. Only this step maps errors to 400/413/415."""
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
                return encoded.getvalue()
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(413, "Image dimensions too large")
    except (UnidentifiedImageError, OSError, ValueError) as e:
        log.warning("ocr_failed status=400 error=%s", type(e).__name__)
        raise HTTPException(400, "Invalid image")


def run_tesseract(png: bytes) -> str:
    """Runs the engine. Failures to start or talk to it are server faults (5xx), never 400."""
    global TESSERACT_LANGS
    ocr_started = time.monotonic()
    try:
        # Piping pixels avoids pytesseract's temporary worksheet file on disk.
        result = subprocess.run(
            ["tesseract", "stdin", "stdout", "-l", "nld+eng", "--psm", "11"],
            input=png, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=30, check=True,
        )
    except FileNotFoundError:
        log.error("ocr_failed status=503 reason=tesseract_not_found")
        raise HTTPException(503, "OCR engine is not installed")
    except OSError as e:
        log.error("ocr_failed status=503 reason=tesseract_unavailable error=%s", type(e).__name__)
        raise HTTPException(503, "OCR engine is unavailable")
    except subprocess.CalledProcessError as e:
        reason = tesseract_failure_reason(e.stderr)
        log.warning("ocr_failed status=502 rc=%s reason=%s", e.returncode, reason)
        if reason == "language_data":
            # Refresh the cached language list so /ready notices data lost after startup.
            TESSERACT_LANGS = _detect_tesseract_langs()
        raise HTTPException(502, "OCR engine failed")
    except subprocess.TimeoutExpired:
        log.warning("ocr_failed status=504 reason=tesseract_timeout")
        raise HTTPException(504, "OCR timed out")
    log.info("ocr_engine duration_ms=%d", (time.monotonic() - ocr_started) * 1000)
    return result.stdout.decode("utf-8", errors="replace")


def recognize(content: bytes) -> dict:
    text = run_tesseract(prepare_image(content))
    places = match_places(text)
    return {"api_version": API_VERSION, "catalog_version": CATALOG_VERSION, "text": text,
            "candidates": [m["name"] for m in places], "candidate_places": places, "review_required": True}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready", response_model=ReadyBody, response_model_exclude_none=True, responses={503: {"model": ReadyBody}})
def ready():
    problems = readiness_problems()
    warnings_ = readiness_warnings()
    if problems:
        # Same top-level shape as success; detail is a string like every other error body.
        return JSONResponse(status_code=503, content={"status": "not_ready", "reasons": problems,
                                                     "warnings": warnings_, "detail": "not_ready: " + ", ".join(problems)})
    return {"status": "ready", "reasons": [], "warnings": warnings_}


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


def per_token_limit(distinct_tokens: int) -> int:
    """With several tokens, one token may hold all slots but one, so it cannot starve the others."""
    slots = configured_slots()
    return max(1, slots - 1) if distinct_tokens > 1 else slots


async def _extract(request: Request):
    token_index, distinct_tokens = authorize(request)
    if CATALOG_PROBLEM:
        raise HTTPException(503, "OCR place catalogue is not available")
    content_type = request.headers.get("content-type", "").split(";", 1)[0].lower()
    if content_type not in {"image/png", "image/jpeg"}:
        raise HTTPException(415, "Use PNG or JPEG")
    if IN_FLIGHT.get(token_index, 0) >= per_token_limit(distinct_tokens) or OCR_SLOTS.locked():
        raise HTTPException(429, "OCR is busy; retry later", headers={"Retry-After": "5"})
    await OCR_SLOTS.acquire()
    IN_FLIGHT[token_index] = IN_FLIGHT.get(token_index, 0) + 1
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
        IN_FLIGHT[token_index] -= 1
        OCR_SLOTS.release()
