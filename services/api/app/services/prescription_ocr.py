"""Bounded, CPU-only handwriting recognition. Images and text are never persisted here."""

import io
import threading
from dataclasses import dataclass
from typing import Any

from app.core.errors import AppException

MODEL_ID = "microsoft/trocr-small-handwritten"
MODEL_REVISION = "b4648cfa171985a6745f37ddd637e98c0da958ac"
MAX_IMAGE_BYTES = 6_000_000
MAX_PIXELS = 16_000_000
MAX_LINES = 24


@dataclass(frozen=True)
class RecognizedLine:
    text: str
    region: tuple[int, int, int, int]


class HandwritingRecognizer:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._processor: Any = None
        self._model: Any = None

    def _load(self) -> None:
        if self._model is not None:
            return
        import torch
        from transformers import TrOCRProcessor, VisionEncoderDecoderModel

        torch.set_num_threads(2)
        processor = TrOCRProcessor.from_pretrained(
            MODEL_ID, revision=MODEL_REVISION, local_files_only=True, use_fast=False
        )
        model_class: Any = VisionEncoderDecoderModel
        model = model_class.from_pretrained(
            MODEL_ID,
            revision=MODEL_REVISION,
            local_files_only=True,
            use_safetensors=False,
            weights_only=True,
        ).eval()
        # Quantize CPU linear layers once; do not ship a full transformer to phones.
        engines = torch.backends.quantized.supported_engines
        engine = next((item for item in ("x86", "fbgemm", "qnnpack") if item in engines), None)
        if engine is not None:
            torch.backends.quantized.engine = engine
            quantize: Any = torch.ao.quantization.quantize_dynamic
            model = quantize(model, {torch.nn.Linear}, dtype=torch.qint8)
        self._processor, self._model = processor, model

    def recognize(self, payload: bytes) -> list[RecognizedLine]:
        if not payload or len(payload) > MAX_IMAGE_BYTES:
            raise AppException("invalid_image_size", "Image must be at most 6 MB.", status_code=413)
        if not self._lock.acquire(blocking=False):
            raise AppException(
                "ocr_busy", "Recognition is busy. Try again shortly.", status_code=429
            )
        try:
            from PIL import Image, ImageOps, UnidentifiedImageError

            try:
                with Image.open(io.BytesIO(payload)) as source:
                    if (
                        source.format not in {"JPEG", "PNG"}
                        or source.width * source.height > MAX_PIXELS
                        or getattr(source, "n_frames", 1) != 1
                    ):
                        raise ValueError("image_dimensions")
                    image = ImageOps.exif_transpose(source).convert("RGB")
            except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
                raise AppException(
                    "invalid_image",
                    "Use a single JPEG or PNG image under 16 megapixels.",
                    status_code=422,
                ) from None
            if min(image.size) < 32:
                raise AppException("invalid_image", "Image is too small to read.", status_code=422)
            image.thumbnail((2200, 2200))
            regions = segment_lines(image)
            if len(regions) > MAX_LINES:
                raise AppException(
                    "too_many_lines", "Crop to at most 24 lines and retry.", status_code=422
                )
            if not regions:
                return []
            self._load()
            import torch

            result = []
            with torch.inference_mode():
                for region in regions:
                    values = self._processor(
                        images=image.crop(region), return_tensors="pt"
                    ).pixel_values
                    tokens = self._model.generate(
                        values, max_new_tokens=96, num_beams=1, do_sample=False
                    )
                    text = self._processor.batch_decode(tokens, skip_special_tokens=True)[0].strip()
                    if text:
                        result.append(RecognizedLine(text, region))
            return result
        except (ImportError, OSError):
            raise AppException(
                "ocr_unavailable",
                "Handwriting model is unavailable. Use manual review or retry later.",
                status_code=503,
            ) from None
        finally:
            self._lock.release()


def segment_lines(image: Any) -> list[tuple[int, int, int, int]]:
    """Adaptive ink threshold and row projection; preserve pixels for the recognizer."""
    import cv2
    import numpy as np

    gray = cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2GRAY)
    mask = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 31, 15
    )
    # Remove tiny speckles without replacing handwriting with a binary image.
    _, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    keep = stats[:, cv2.CC_STAT_AREA] >= 5
    keep[0] = False
    mask = (keep[labels] * 255).astype("uint8")
    active = (mask > 0).sum(axis=1) >= max(3, image.width * 0.003)
    spans: list[tuple[int, int]] = []
    start: int | None = None
    last = 0
    gap = max(3, image.height // 250)
    for y, ink in enumerate(active):
        if ink:
            if start is None:
                start = y
            last = y
        elif start is not None and y - last > gap:
            spans.append((start, last + 1))
            start = None
    if start is not None:
        spans.append((start, last + 1))
    regions = []
    for top, bottom in spans:
        columns = np.flatnonzero((mask[top:bottom] > 0).sum(axis=0))
        if bottom - top < 5 or len(columns) < 10:
            continue
        regions.append(
            (
                max(0, int(columns[0]) - 8),
                max(0, top - 8),
                min(image.width, int(columns[-1]) + 9),
                min(image.height, bottom + 8),
            )
        )
    return regions
