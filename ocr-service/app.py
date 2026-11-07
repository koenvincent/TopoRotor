"""Authenticated, bounded OCR endpoint. Worksheet bytes never persist to disk."""
import asyncio
import io
import json
import os
import re
import secrets
import subprocess
import unicodedata
import warnings
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

app = FastAPI(title="TopoRotor OCR", version="0.2.0")
CATALOG = json.loads((Path(__file__).resolve().parents[1] / "data" / "places.json").read_text())
MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 12_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS
# Includes uploads and decoding, so multiple slow uploads cannot exhaust image RAM.
OCR_SLOTS = asyncio.Semaphore(2)


def normalized(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.casefold())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", text.replace("-", " ").replace("'", "")).strip()


def candidates(text: str) -> list[str]:
    text = normalized(text)
    matches = []
    for p in CATALOG:
        for alias in [p["name"], *p.get("aliases", [])]:
            if re.search(r"(?<!\w)" + re.escape(normalized(alias)) + r"(?!\w)", text):
                matches.append(p["name"])
                break
    return matches


def authorize(request: Request) -> None:
    token = os.environ.get("TOPOROTOR_OCR_TOKEN", "")
    if len(token.encode("utf-8")) < 32:
        raise HTTPException(503, "OCR authentication is not configured")
    supplied = request.headers.get("authorization", "")
    if not secrets.compare_digest(supplied.encode("utf-8"), ("Bearer " + token).encode("utf-8")):
        raise HTTPException(401, "Invalid OCR token", headers={"WWW-Authenticate": "Bearer"})


def recognize(content: bytes) -> dict:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(content)) as source:
                # Validate dimensions before exif_transpose/load decode image pixels.
                if source.width * source.height > MAX_PIXELS:
                    raise HTTPException(413, "Image dimensions too large")
                if source.format not in {"PNG", "JPEG"}:
                    raise HTTPException(415, "Use PNG or JPEG")
                image = ImageOps.exif_transpose(source)
                image.thumbnail((1800, 1800))
                image = ImageOps.grayscale(image)
                encoded = io.BytesIO()
                image.save(encoded, format="PNG")
                # Piping pixels avoids pytesseract's temporary worksheet file on disk.
                result = subprocess.run(
                    ["tesseract", "stdin", "stdout", "-l", "nld+eng", "--psm", "11"],
                    input=encoded.getvalue(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    timeout=30, check=True,
                )
                text = result.stdout.decode("utf-8", errors="replace")
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(413, "Image dimensions too large")
    except FileNotFoundError:
        raise HTTPException(503, "OCR engine is not installed")
    except subprocess.CalledProcessError:
        raise HTTPException(502, "OCR engine failed")
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(400, "Invalid image")
    except subprocess.TimeoutExpired:
        raise HTTPException(504, "OCR timed out")
    return {"text": text, "candidates": candidates(text), "review_required": True}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/extract")
async def extract(request: Request):
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
        # Decoding + Tesseract must not block FastAPI's event loop.
        return await run_in_threadpool(recognize, bytes(content))
    finally:
        OCR_SLOTS.release()
