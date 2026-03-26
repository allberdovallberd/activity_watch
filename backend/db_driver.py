from __future__ import annotations

from typing import Any

try:
    import psycopg as _driver
    from psycopg.rows import dict_row

    Error = _driver.Error
    Connection = _driver.Connection

    def connect(dsn: str, *, row_factory: Any | None = None):
        kwargs: dict[str, Any] = {}
        if row_factory is not None:
            kwargs["row_factory"] = row_factory
        return _driver.connect(dsn, **kwargs)

except ImportError:
    import psycopg2 as _driver
    from psycopg2.extras import RealDictConnection

    Error = _driver.Error
    Connection = Any
    dict_row = object()

    def connect(dsn: str, *, row_factory: Any | None = None):
        return _driver.connect(dsn, connection_factory=RealDictConnection)
