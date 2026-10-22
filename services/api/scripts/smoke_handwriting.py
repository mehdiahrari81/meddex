"""Operator smoke test on a public handwriting fixture; never creates patient records."""

import io
import time

import httpx
from PIL import Image

from app.services.prescription_ocr import HandwritingRecognizer

url = (
    "https://huggingface.co/datasets/hf-internal-testing/fixtures_ocr/resolve/main/iam_picture.jpeg"
)
response = httpx.get(url, timeout=30, follow_redirects=True)
response.raise_for_status()
print("Fixture:", url, Image.open(io.BytesIO(response.content)).size, flush=True)
recognizer = HandwritingRecognizer()
for label in ("cold", "warm"):
    start = time.perf_counter()
    lines = recognizer.recognize(response.content)
    print(label, round(time.perf_counter() - start, 3), [line.text for line in lines], flush=True)
