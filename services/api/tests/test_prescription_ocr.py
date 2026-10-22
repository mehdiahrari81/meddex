import io

import pytest
from fastapi.testclient import TestClient

from app.core.errors import AppException
from app.services.prescription_ocr import HandwritingRecognizer, RecognizedLine, segment_lines
from tests.conftest import auth_headers


def test_ocr_requires_authenticated_account(client: TestClient) -> None:
    assert (
        client.post(
            "/api/v1/prescription-ocr/handwriting",
            content=b"x",
            headers={"Content-Type": "image/jpeg"},
        ).status_code
        == 401
    )


def test_ocr_never_confirms_output(client: TestClient, registered: dict[str, str]) -> None:
    class Recognizer:
        def recognize(self, payload: bytes) -> list[RecognizedLine]:
            assert payload == b"private-image"
            return [RecognizedLine("unclear medicine 5? mg", (0, 0, 100, 20))]

    client.app.state.handwriting_recognizer = Recognizer()
    headers = auth_headers(registered["access_token"]) | {"Content-Type": "image/jpeg"}
    response = client.post(
        "/api/v1/prescription-ocr/handwriting", headers=headers, content=b"private-image"
    )
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    assert response.json()["requires_review"] is True
    assert response.json()["lines"][0]["confidence"] is None
    assert response.json()["lines"][0]["requires_review"] is True
    assert (
        client.post(
            "/api/v1/prescription-ocr/handwriting", headers=headers, content=b"x" * 6_000_001
        ).status_code
        == 413
    )
    headers["Content-Type"] = "image/svg+xml"
    assert (
        client.post(
            "/api/v1/prescription-ocr/handwriting", headers=headers, content=b"<svg/>"
        ).status_code
        == 415
    )


def test_invalid_image_and_busy_worker() -> None:
    pytest.importorskip("PIL")
    recognizer = HandwritingRecognizer()
    with pytest.raises(AppException, match="Use a single"):
        recognizer.recognize(b"not an image")
    recognizer._lock.acquire()
    try:
        with pytest.raises(AppException, match="busy"):
            recognizer.recognize(b"image")
    finally:
        recognizer._lock.release()


def test_segmentation_finds_lines_and_ignores_blank_pages() -> None:
    pytest.importorskip("cv2")
    from PIL import Image, ImageDraw

    image = Image.new("RGB", (600, 200), "white")
    assert segment_lines(image) == []
    draw = ImageDraw.Draw(image)
    draw.text((20, 25), "Amoxicillin 500 mg", fill="black", font_size=26)
    draw.text((20, 100), "Review dose with pharmacist", fill="black", font_size=26)
    assert len(segment_lines(image)) == 2
    blank = io.BytesIO()
    Image.new("RGB", (100, 100), "white").save(blank, format="PNG")
    assert HandwritingRecognizer().recognize(blank.getvalue()) == []
