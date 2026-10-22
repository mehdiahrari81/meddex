import base64
import io
import json

import httpx
import pytest
from PIL import Image, ImageDraw
from pydantic import SecretStr

from app.core.config import Settings
from app.services.gemini_handwriting import (
    RecheckedLine,
    TranscribedLine,
    _merge_rechecked_line,
    transcribe_handwriting,
)
from app.services.handwriting_views import MAX_VIEW_BYTES, handwriting_views


def page_bytes() -> bytes:
    output = io.BytesIO()
    page = Image.new("RGB", (1200, 1800), "white")
    draw = ImageDraw.Draw(page)
    # Synthetic pen strokes at page boundaries and crop overlaps.
    for y in (10, 650, 820, 1300, 1780):
        draw.line((25, y, 1100, y), fill=(80, 100, 170), width=3)
    exif = Image.Exif()
    exif[315] = "Private metadata fixture"
    page.save(output, format="JPEG", exif=exif)
    return output.getvalue()


def test_detail_views_cover_the_whole_page_overlap_and_strip_metadata() -> None:
    page = Image.open(io.BytesIO(page_bytes())).convert("RGB")
    views = handwriting_views(page)
    assert len(views) == 4
    assert sum(map(len, views)) <= MAX_VIEW_BYTES
    images = [Image.open(io.BytesIO(raw)) for raw in views]
    assert all(not image.getexif() for image in images)
    assert images[0].size == (1200, 1800)
    assert all(image.size == (1200, 828) for image in images[1:])
    assert images[1].getpixel((200, 650))[0] < 200
    assert images[-1].getpixel((200, 1780 - 972))[0] < 200
    assert page.getpixel((200, 650))[2] > page.getpixel((200, 650))[0]


def test_detail_views_are_bounded_on_noisy_images_and_keep_small_images_simple() -> None:
    noisy = Image.effect_noise((2000, 3000), 100).convert("RGB")
    views = handwriting_views(noisy)
    assert 1 <= len(views) <= 4
    assert sum(map(len, views)) <= MAX_VIEW_BYTES
    small = Image.new("RGB", (300, 100), "white")
    assert len(handwriting_views(small)) == 1
    assert len(handwriting_views(small, enhance=True)) == 2


def test_recheck_recovers_name_but_does_not_confirm_it_or_change_clear_dose() -> None:
    original = TranscribedLine(
        text="[illegible] 50 mg BD", uncertain=True, uncertain_spans=["[illegible]"]
    )
    recovered = _merge_rechecked_line(
        original,
        RecheckedLine(
            line_index=0,
            text="Betaloc 50 mg BD",
            uncertain=False,
        ),
    )
    assert recovered.text == "Betaloc 50 mg BD"
    assert recovered.uncertain
    assert recovered.uncertain_spans == ["Betaloc"]
    changed_dose = _merge_rechecked_line(
        original,
        RecheckedLine(
            line_index=0,
            text="Betaloc 100 mg BD",
            uncertain=False,
        ),
    )
    assert changed_dose is original
    dropped_frequency = _merge_rechecked_line(
        original,
        RecheckedLine(
            line_index=0,
            text="Betaloc 50 mg",
            uncertain=False,
        ),
    )
    assert dropped_frequency is original


def test_changed_letters_are_flagged_as_words_not_every_identical_letter() -> None:
    recovered = _merge_rechecked_line(
        TranscribedLine(text="Met?prolol 50 mg BD", uncertain=True),
        RecheckedLine(line_index=0, text="Metoprolol 50 mg BD", uncertain=False),
    )
    assert recovered.uncertain_spans == ["Metoprolol"]


@pytest.mark.parametrize("failure", [False, True])
def test_cloud_detail_reading_and_bounded_recheck_preserve_first_result(failure: bool) -> None:
    calls = []

    def respond(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        calls.append(body)
        images = [
            part["inlineData"] for part in body["contents"][0]["parts"] if "inlineData" in part
        ]
        assert len(images) == 4
        assert all(
            not Image.open(io.BytesIO(base64.b64decode(i["data"]))).getexif() for i in images
        )
        assert body["generationConfig"]["mediaResolution"] == "MEDIA_RESOLUTION_HIGH"
        if len(calls) == 1:
            result = {
                "lines": [
                    {"text": "[illegible] 50 mg BD", "uncertain": True},
                    {"text": "Metformin 500 mg OD", "uncertain": False},
                ]
            }
        else:
            if failure:
                return httpx.Response(429)
            result = {
                "lines": [
                    {"line_index": 0, "text": "Betaloc 50 mg BD", "uncertain": False},
                ]
            }
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {"parts": [{"text": json.dumps(result)}]},
                    }
                ]
            },
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(
            Settings(gemini_api_key=SecretStr("qa")), client, page_bytes()
        )
    assert len(calls) == 2
    assert result["detail_review_attempted"] is True
    assert result["detail_review_completed"] is not failure
    assert result["uncertain_line_numbers"] == [1]
    assert result["requires_review"] is True
    assert "Metformin 500 mg OD" in result["text"]
    assert (
        "[illegible] 50 mg BD" in result["text"]
        if failure
        else "[uncertain: Betaloc] 50 mg BD" in result["text"]
    )


@pytest.mark.parametrize("uncertain", [False, True])
def test_clear_pages_use_one_call_and_retry_cannot_edit_other_lines(uncertain: bool) -> None:
    calls = []

    def respond(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        result = (
            {
                "lines": [
                    {"text": "Betaloc 50 mg BD", "uncertain": uncertain},
                    {"text": "Metformin 500 mg OD", "uncertain": False},
                ]
            }
            if len(calls) == 1
            else {
                "lines": [
                    {"line_index": 1, "text": "Metformin 1000 mg OD", "uncertain": False},
                ]
            }
        )
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {"parts": [{"text": json.dumps(result)}]},
                    }
                ]
            },
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(
            Settings(gemini_api_key=SecretStr("qa")), client, page_bytes()
        )
    assert len(calls) == (2 if uncertain else 1)
    assert result["detail_review_completed"] is False
    assert "Metformin 500 mg OD" in result["text"]


@pytest.mark.parametrize("status, expected_calls", [(503, 2), (429, 1)])
def test_primary_transient_retry_is_bounded_and_does_not_retry_quota(
    status: int,
    expected_calls: int,
) -> None:
    calls = []

    def respond(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if len(calls) == 1:
            return httpx.Response(status)
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps(
                                        {
                                            "lines": [
                                                {"text": "Betaloc 50 mg BD", "uncertain": False},
                                            ]
                                        }
                                    )
                                }
                            ]
                        },
                    }
                ]
            },
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        if status == 429:
            with pytest.raises(httpx.HTTPStatusError):
                transcribe_handwriting(
                    Settings(gemini_api_key=SecretStr("qa")), client, page_bytes()
                )
        else:
            result = transcribe_handwriting(
                Settings(gemini_api_key=SecretStr("qa")), client, page_bytes()
            )
            assert result["text"] == "Betaloc 50 mg BD"
            assert result["model"] == "gemini-3.1-flash-lite"
            assert "gemini-3.1-flash-lite:generateContent" in str(calls[-1].url)
    assert len(calls) == expected_calls


def test_second_reader_can_add_uncertainty_without_erasing_original_doubts() -> None:
    original = TranscribedLine(text="Betaloc 50 mg BD", uncertain=True, uncertain_spans=["50 mg"])
    revised = _merge_rechecked_line(
        original,
        RecheckedLine(
            line_index=0,
            text=original.text,
            uncertain=True,
            uncertain_spans=["Betaloc"],
        ),
    )
    assert revised.uncertain
    assert set(revised.uncertain_spans) == {"Betaloc", "50 mg"}
    clear_second_opinion = _merge_rechecked_line(
        original,
        RecheckedLine(
            line_index=0,
            text=original.text,
            uncertain=False,
        ),
    )
    assert clear_second_opinion is original
