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

    class _CompatConnection:
        def __init__(self, conn: Any):
            self._conn = conn

        def execute(self, query: str, params: Any = None):
            cur = self._conn.cursor()
            cur.execute(query, params or ())
            return cur

        def __getattr__(self, name: str):
            return getattr(self._conn, name)

        def __enter__(self):
            self._conn.__enter__()
            return self

        def __exit__(self, exc_type, exc, tb):
            return self._conn.__exit__(exc_type, exc, tb)

    def connect(dsn: str, *, row_factory: Any | None = None):
        conn = _driver.connect(dsn, connection_factory=RealDictConnection)
        return _CompatConnection(conn)
