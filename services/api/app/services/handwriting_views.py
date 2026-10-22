"""Bounded, metadata-free detail views of one page; no files or ML dependencies."""

import io

from PIL import Image, ImageOps

MAX_VIEW_BYTES = 8_000_000  # Base64 + prompts stay below Gemini's 20 MB inline limit.


def _jpeg(image: Image.Image) -> bytes:
    working = image.copy()
    while True:
        output = io.BytesIO()
        working.save(output, format="JPEG", quality=95)
        encoded = output.getvalue()
        if len(encoded) <= 4_000_000:
            return encoded
        working.thumbnail(
            (max(32, round(working.width * 0.85)), max(32, round(working.height * 0.85)))
        )


def handwriting_views(image: Image.Image, *, enhance: bool = False) -> list[bytes]:
    """Keep the unmodified page as context and overlap crops to retain joined lines."""
    page = image.copy()
    page.thumbnail((3200, 3200))
    original = _jpeg(page)
    views = [original]
    used = len(original)
    regions = []
    width, height = page.size
    if height >= 1200 and width >= 640 and height >= width:
        # Three full-width bands, with overlap for descenders and continuation lines.
        band_height = round(height * 0.46)
        for fraction in (0, 0.27, 0.54):
            top = round(height * fraction)
            regions.append(page.crop((0, top, width, min(height, top + band_height))))
    elif enhance:
        regions.append(page.copy())
    for region in regions:
        if enhance:
            # Preserve pale pen strokes: no binarization, erasing or generated pixels.
            region = ImageOps.autocontrast(ImageOps.grayscale(region), cutoff=0).convert("RGB")
        region.thumbnail((2200, 2200))
        encoded = _jpeg(region)
        if used + len(encoded) <= MAX_VIEW_BYTES:
            views.append(encoded)
            used += len(encoded)
    return views
