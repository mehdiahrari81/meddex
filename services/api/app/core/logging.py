import logging
import re
import sys
from typing import Any, cast

import structlog
from structlog.typing import EventDict

SENSITIVE_KEY = re.compile(
    r"password|token|authorization|cookie|prescription|medication", re.IGNORECASE
)


def _redact(_: Any, __: str, event_dict: EventDict) -> EventDict:
    return {
        key: "[REDACTED]" if SENSITIVE_KEY.search(key) else value
        for key, value in event_dict.items()
    }


def configure_logging(level: str) -> None:
    logging.basicConfig(stream=sys.stdout, level=level, format="%(message)s")
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            _redact,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelNamesMapping().get(level.upper(), logging.INFO)
        ),
    )


def get_logger() -> structlog.stdlib.BoundLogger:
    return cast(structlog.stdlib.BoundLogger, structlog.get_logger())
