"""
NAADYANTRA Timezone and Datetime Utilities.

Provides a unified, consistent timezone-handling strategy across FastAPI,
SQLAlchemy, PostgreSQL (Neon), and SQLite.

All application logic prefers timezone-aware UTC datetimes. Database columns
defined as TIMESTAMP WITHOUT TIME ZONE (default in PostgreSQL and SQLite)
store UTC timestamps without offset information. When read from the database,
`to_utc_datetime` normalizes them to timezone-aware UTC so that all in-memory
comparisons, staleness calculations, and Pydantic serialization are safe,
exact, and free of TypeError exceptions.
"""

from datetime import datetime, timezone
from typing import Optional


def to_utc_datetime(dt: Optional[datetime]) -> Optional[datetime]:
    """Normalize any datetime (naive or aware) to a timezone-aware UTC datetime.

    - If dt is None, returns None.
    - If dt is naive (no tzinfo, as returned by PostgreSQL TIMESTAMP WITHOUT TIME ZONE
      or SQLite), it is treated as UTC and its tzinfo is set to timezone.utc.
    - If dt is already timezone-aware, it is converted to UTC using astimezone(timezone.utc).
    """
    if dt is None:
        return None
    if dt.tzinfo is None or dt.tzinfo.utcoffset(dt) is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def utc_now() -> datetime:
    """Return the current time as a timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)
