import asyncio

import pytest
from fastapi import Request

from app.api.v1.routers.prescription_ocr import _read_image
from app.core.errors import AppException


def test_interrupted_upload_is_an_expected_error_not_an_internal_server_failure():
    messages = iter(
        [
            {"type": "http.request", "body": b"partial", "more_body": True},
            {"type": "http.disconnect"},
        ]
    )

    async def receive():
        return next(messages)

    request = Request({"type": "http", "headers": [(b"content-type", b"image/jpeg")]}, receive)
    with pytest.raises(AppException) as error:
        asyncio.run(_read_image(request))
    assert error.value.code == "image_upload_interrupted"
    assert error.value.status_code == 408


def test_complete_upload_retains_every_chunk():
    messages = iter(
        [
            {"type": "http.request", "body": b"first", "more_body": True},
            {"type": "http.request", "body": b"second", "more_body": False},
        ]
    )

    async def receive():
        return next(messages)

    request = Request({"type": "http", "headers": [(b"content-type", b"image/jpeg")]}, receive)
    assert asyncio.run(_read_image(request)) == b"firstsecond"
