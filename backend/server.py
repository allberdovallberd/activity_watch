import json
import os
import queue
import threading
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

import db_driver as psycopg
from db_driver import dict_row

from admin_actions import (
    ensure_admin_credentials,
    ensure_admin_settings,
    ensure_default_web_user,
    get_authorized_token_type,
    handle_admin_login,
    handle_admin_set_credentials,
    handle_create_web_user,
    handle_delete_web_user,
    handle_get_web_users,
    handle_update_web_user_password,
    handle_update_web_user,
    handle_user_login,
)

def _load_dotenv() -> None:
    candidates = [
        Path(__file__).resolve().parent / ".env",
        Path.cwd() / ".env",
    ]
    for path in candidates:
        if not path.exists():
            continue
        try:
            for raw in path.read_text(encoding="utf-8").splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = value
        except Exception:
            continue


_load_dotenv()

DB_DSN = os.getenv("USAGE_DB_DSN") or os.getenv("DATABASE_URL")
HOST = os.getenv("USAGE_SERVER_HOST", "0.0.0.0")
PORT = int(os.getenv("USAGE_SERVER_PORT", "8080"))
ADMIN_TOKEN_HOURS = int(os.getenv("USAGE_ADMIN_TOKEN_HOURS", "12"))
ADMIN_PANEL_USERNAME = os.getenv("USAGE_ADMIN_USERNAME", "").strip()
ADMIN_PANEL_PASSWORD = os.getenv("USAGE_ADMIN_PASSWORD", "").strip()
DEFAULT_WEB_USERNAME = os.getenv("USAGE_DEFAULT_WEB_USERNAME", "").strip()
DEFAULT_WEB_PASSWORD = os.getenv("USAGE_DEFAULT_WEB_PASSWORD", "").strip()
DB_POOL_MIN_SIZE = max(1, int(os.getenv("USAGE_DB_POOL_MIN_SIZE", "4")))
DB_POOL_MAX_SIZE = max(DB_POOL_MIN_SIZE, int(os.getenv("USAGE_DB_POOL_MAX_SIZE", "24")))
RETENTION_DAYS = 62
RETENTION_CLEANUP_INTERVAL_SECONDS = max(300, int(os.getenv("USAGE_RETENTION_CLEANUP_SECONDS", "3600")))

SYSTEM_PACKAGE_PREFIXES = (
    "android",
    "com.android.systemui",
    "com.android.settings",
    "com.android.launcher",
    "com.android.launcher3",
    "com.android.storagemanager",
    "com.android.permissioncontroller",
    "com.android.packageinstaller",
    "com.android.providers.",
    "com.android.inputmethod",
    "com.android.shell",
    "com.android.phone",
    "com.android.server.telecom",
    "com.android.bluetooth",
    "com.android.nfc",
    "com.android.cellbroadcast",
    "com.android.printspooler",
    "com.android.managedprovisioning",
    "com.android.calendar",
    "com.android.contacts",
    "com.google.android.gsf",
    "com.google.android.syncadapters.",
    "com.google.android.setupwizard",
    "com.google.android.apps.wellbeing",
    "com.topjohnwu.magisk",
    "com.mediatek.",
)

SYSTEM_NAME_KEYWORDS = (
    "settings",
    "system ui",
    "android system",
    "launcher",
    "android setup",
    "setup wizard",
    "restore",
    "permission controller",
    "package installer",
    "input method",
    "print spooler",
    "carrier services",
    "telecom",
    "sim toolkit",
    "downloads",
    "storage",
    "sync",
    "framework",
    "gms policy",
    "google gms policy",
    "policy",
    "mediatek",
    "digital wellbeing",
    "headwind mdm",
    "mdm agent",
    "musicfx",
    "phone services",
    "root explorer",
    "magisk",
)

USER_FACING_PACKAGE_PREFIXES = (
    "com.android.chrome",
    "com.android.browser",
    "com.android.gallery",
    "com.android.calculator",
    "com.android.music",
    "com.android.email",
    "com.android.dialer",
    "com.android.camera",
    "com.android.fmradio",
    "com.android.vending",
    "com.google.android.apps.",
    "com.google.android.youtube",
    "com.google.android.calendar",
    "com.google.android.contacts",
    "com.google.android.gm",
    "com.google.android.music",
    "com.google.android.videos",
    "com.google.android.apps.photos",
    "com.google.android.apps.maps",
    "com.google.android.apps.nbu",
    "com.google.android.apps.messaging",
    "com.google.android.play.games",
)

USER_FACING_NAME_KEYWORDS = (
    "chrome",
    "browser",
    "music",
    "gallery",
    "photos",
    "calculator",
    "camera",
    "radio",
    "fm radio",
    "movies",
    "video",
    "youtube",
    "maps",
    "gmail",
    "email",
    "drive",
    "calendar",
    "clock",
    "contacts",
    "messages",
    "messaging",
    "play games",
    "play store",
    "files",
    "recorder",
)

SYSTEM_STYLE_NAME_KEYWORDS = (
    "storage",
    "sync",
    "framework",
    "policy",
    "setup",
    "service",
    "services",
    "wellbeing",
    "musicfx",
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _validate_bootstrap_pair(name: str, username: str, password: str) -> None:
    if bool(username) != bool(password):
        raise RuntimeError(
            f"{name} bootstrap requires both username and password to be set, or both left empty"
        )


def _json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        if value == value.to_integral_value():
            return int(value)
        return float(value)
    raise TypeError(f"Type {type(value)} is not JSON serializable")


def _coerce_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "t", "yes", "y")
    return False


def _starts_with_any_prefix(value: str, prefixes: tuple[str, ...]) -> bool:
    return any(value == prefix or value.startswith(f"{prefix}.") or value.startswith(prefix) for prefix in prefixes)


def _includes_any_keyword(value: str, keywords: tuple[str, ...]) -> bool:
    return any(keyword in value for keyword in keywords)


def _is_user_facing_preinstalled_app(package_name: str, app_name: str) -> bool:
    if _starts_with_any_prefix(package_name, USER_FACING_PACKAGE_PREFIXES):
        return True
    if _includes_any_keyword(app_name, SYSTEM_STYLE_NAME_KEYWORDS):
        return False
    return _includes_any_keyword(app_name, USER_FACING_NAME_KEYWORDS)


def _is_core_system_app(package_name: str, app_name: str) -> bool:
    return _starts_with_any_prefix(package_name, SYSTEM_PACKAGE_PREFIXES) or _includes_any_keyword(
        app_name, SYSTEM_NAME_KEYWORDS
    )


def _classify_is_system(package_name: str, app_name: str, raw_is_system: Any) -> bool:
    normalized_package = str(package_name or "").lower()
    normalized_name = str(app_name or "").lower()
    if _is_core_system_app(normalized_package, normalized_name):
        return True
    if _is_user_facing_preinstalled_app(normalized_package, normalized_name):
        return False
    return _coerce_bool(raw_is_system)


def parse_iso8601(raw: str) -> str:
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    dt = datetime.fromisoformat(raw)
    if not dt.tzinfo:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()

def _parse_include_system(query: dict[str, list[str]]) -> bool:
    raw = query.get("include_system", ["true"])[0]
    return _coerce_bool(raw)


class _PooledConnection:
    def __init__(self, pool: "_ConnectionPool", conn: psycopg.Connection):
        self._pool = pool
        self._conn = conn
        self._released = False

    def __getattr__(self, name: str) -> Any:
        return getattr(self._conn, name)

    def close(self) -> None:
        if self._released:
            return
        self._released = True
        self._pool.release(self._conn)

    def __enter__(self) -> "_PooledConnection":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        self.close()
        return False


class _ConnectionPool:
    def __init__(self, dsn: str, *, min_size: int, max_size: int):
        self._dsn = dsn
        self._min_size = min_size
        self._max_size = max_size
        self._available: "queue.LifoQueue[psycopg.Connection]" = queue.LifoQueue(maxsize=max_size)
        self._lock = threading.Lock()
        self._total = 0

    def _new_connection(self) -> psycopg.Connection:
        conn = psycopg.connect(self._dsn, row_factory=dict_row)
        conn.execute("SET TIME ZONE 'UTC'")
        return conn

    def warm_up(self) -> None:
        while True:
            with self._lock:
                if self._total >= self._min_size:
                    return
                self._total += 1
            try:
                conn = self._new_connection()
            except Exception:
                with self._lock:
                    self._total -= 1
                raise
            self._available.put(conn)

    def acquire(self, timeout: float = 10.0) -> _PooledConnection:
        try:
            conn = self._available.get_nowait()
            return _PooledConnection(self, conn)
        except queue.Empty:
            pass

        with self._lock:
            if self._total < self._max_size:
                self._total += 1
                create_new = True
            else:
                create_new = False

        if create_new:
            try:
                return _PooledConnection(self, self._new_connection())
            except Exception:
                with self._lock:
                    self._total -= 1
                raise

        conn = self._available.get(timeout=timeout)
        return _PooledConnection(self, conn)

    def release(self, conn: psycopg.Connection) -> None:
        try:
            if getattr(conn, "closed", False):
                self._discard(conn)
                return
            try:
                conn.rollback()
            except Exception:
                self._discard(conn)
                return
            self._available.put_nowait(conn)
        except queue.Full:
            self._discard(conn)

    def _discard(self, conn: psycopg.Connection) -> None:
        try:
            conn.close()
        except Exception:
            pass
        with self._lock:
            self._total = max(0, self._total - 1)

    def close_all(self) -> None:
        while True:
            try:
                conn = self._available.get_nowait()
            except queue.Empty:
                break
            try:
                conn.close()
            except Exception:
                pass
        with self._lock:
            self._total = 0


_db_pool: _ConnectionPool | None = None
_db_pool_lock = threading.Lock()
_retention_stop_event = threading.Event()
_retention_thread: threading.Thread | None = None


def _get_db_pool() -> _ConnectionPool:
    global _db_pool
    if _db_pool is not None:
        return _db_pool
    with _db_pool_lock:
        if _db_pool is None:
            pool = _ConnectionPool(DB_DSN, min_size=DB_POOL_MIN_SIZE, max_size=DB_POOL_MAX_SIZE)
            pool.warm_up()
            _db_pool = pool
    return _db_pool


def db_connect() -> _PooledConnection:
    if not DB_DSN:
        raise RuntimeError("Missing USAGE_DB_DSN or DATABASE_URL for PostgreSQL connection")
    return _get_db_pool().acquire()


def init_db() -> None:
    _validate_bootstrap_pair("Admin", ADMIN_PANEL_USERNAME, ADMIN_PANEL_PASSWORD)
    _validate_bootstrap_pair("Default web user", DEFAULT_WEB_USERNAME, DEFAULT_WEB_PASSWORD)
    conn = db_connect()
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS main_categories (
                id BIGSERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_main_categories_name UNIQUE (name)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sub_categories (
                id BIGSERIAL PRIMARY KEY,
                main_category_id BIGINT NOT NULL
                    REFERENCES main_categories(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_sub_categories_main_name UNIQUE (main_category_id, name)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                display_name TEXT,
                main_category_id BIGINT REFERENCES main_categories(id) ON DELETE SET NULL,
                sub_category_id BIGINT REFERENCES sub_categories(id) ON DELETE SET NULL,
                status TEXT NOT NULL DEFAULT 'active',
                bound_client_id TEXT,
                device_token TEXT,
                bound_at TIMESTAMPTZ,
                last_seen_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL,
                updated_at TIMESTAMPTZ NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_devices_status_category_device
              ON devices(status, main_category_id, sub_category_id, device_id)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_devices_status_last_seen
              ON devices(status, last_seen_at DESC, device_id)
            """
        )
        conn.execute("ALTER TABLE devices ADD COLUMN IF NOT EXISTS device_token TEXT")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS device_tombstones (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL,
                blocked_client_id TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_device_tombstones_device_blocked UNIQUE (device_id, blocked_client_id)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS apps (
                device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
                package_name TEXT NOT NULL,
                app_name TEXT NOT NULL,
                icon_base64 TEXT,
                is_system BOOLEAN NOT NULL DEFAULT FALSE,
                is_tracking BOOLEAN NOT NULL DEFAULT FALSE,
                updated_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT pk_apps PRIMARY KEY (device_id, package_name)
            )
            """
        )
        conn.execute("ALTER TABLE apps ADD COLUMN IF NOT EXISTS is_system BOOLEAN NOT NULL DEFAULT FALSE")
        conn.execute("ALTER TABLE apps ADD COLUMN IF NOT EXISTS is_tracking BOOLEAN NOT NULL DEFAULT FALSE")
        conn.execute("ALTER TABLE apps ADD COLUMN IF NOT EXISTS inventory_sync_id TEXT")
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_apps_device_inventory_sync
              ON apps(device_id, inventory_sync_id)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS app_presence_periods (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
                package_name TEXT NOT NULL,
                app_name TEXT NOT NULL,
                icon_base64 TEXT,
                is_system BOOLEAN NOT NULL DEFAULT FALSE,
                is_tracking BOOLEAN NOT NULL DEFAULT FALSE,
                installed_at TIMESTAMPTZ NOT NULL,
                last_seen_at TIMESTAMPTZ NOT NULL,
                removed_at TIMESTAMPTZ
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_presence_device_package_active
              ON app_presence_periods(device_id, package_name, removed_at)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_presence_device_package_open
              ON app_presence_periods(device_id, package_name, installed_at DESC)
              WHERE removed_at IS NULL
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_presence_device_installed_removed
              ON app_presence_periods(device_id, installed_at, removed_at)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_presence_removed_at
              ON app_presence_periods(removed_at)
              WHERE removed_at IS NOT NULL
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS usage_sessions (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
                package_name TEXT NOT NULL,
                start_time TIMESTAMPTZ NOT NULL,
                end_time TIMESTAMPTZ NOT NULL,
                foreground_ms BIGINT NOT NULL,
                synced_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_usage_sessions_device_package_time
                    UNIQUE (device_id, package_name, start_time, end_time)
            )
            """
        )
        conn.execute("ALTER TABLE usage_sessions DROP CONSTRAINT IF EXISTS uq_usage_sessions_device_package_time")
        conn.execute(
            """
            DELETE FROM usage_sessions a
            USING usage_sessions b
            WHERE a.id < b.id
              AND a.device_id = b.device_id
              AND a.package_name = b.package_name
              AND a.start_time = b.start_time
            """
        )
        conn.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_usage_device_package_start
              ON usage_sessions(device_id, package_name, start_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_usage_device_time
              ON usage_sessions(device_id, start_time, end_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_usage_end_time
              ON usage_sessions(end_time)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS data_usage_sessions (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
                start_time TIMESTAMPTZ NOT NULL,
                end_time TIMESTAMPTZ NOT NULL,
                total_bytes BIGINT NOT NULL,
                synced_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_data_usage_sessions_device_time UNIQUE (device_id, start_time, end_time)
            )
            """
        )
        conn.execute("ALTER TABLE data_usage_sessions DROP CONSTRAINT IF EXISTS uq_data_usage_sessions_device_time")
        conn.execute(
            """
            DELETE FROM data_usage_sessions a
            USING data_usage_sessions b
            WHERE a.id < b.id
              AND a.device_id = b.device_id
              AND a.start_time = b.start_time
            """
        )
        conn.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_data_usage_device_start
              ON data_usage_sessions(device_id, start_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_data_usage_device_time
              ON data_usage_sessions(device_id, start_time, end_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_data_usage_end_time
              ON data_usage_sessions(end_time)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS app_data_usage_sessions (
                id BIGSERIAL PRIMARY KEY,
                device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
                package_name TEXT NOT NULL,
                start_time TIMESTAMPTZ NOT NULL,
                end_time TIMESTAMPTZ NOT NULL,
                total_bytes BIGINT NOT NULL,
                synced_at TIMESTAMPTZ NOT NULL
            )
            """
        )
        conn.execute(
            """
            DELETE FROM app_data_usage_sessions a
            USING app_data_usage_sessions b
            WHERE a.id < b.id
              AND a.device_id = b.device_id
              AND a.package_name = b.package_name
              AND a.start_time = b.start_time
            """
        )
        conn.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_app_data_usage_device_pkg_start
              ON app_data_usage_sessions(device_id, package_name, start_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_data_usage_device_time
              ON app_data_usage_sessions(device_id, start_time, end_time)
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_app_data_usage_end_time
              ON app_data_usage_sessions(end_time)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_credentials (
                id BIGSERIAL PRIMARY KEY,
                username TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                updated_at TIMESTAMPTZ NOT NULL,
                CONSTRAINT uq_admin_credentials_username UNIQUE (username)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS web_users (
                username TEXT PRIMARY KEY,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                updated_at TIMESTAMPTZ NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                allow_bootstrap BOOLEAN NOT NULL DEFAULT TRUE,
                updated_at TIMESTAMPTZ NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_tokens (
                token TEXT PRIMARY KEY,
                token_type TEXT NOT NULL DEFAULT 'admin',
                expires_at TIMESTAMPTZ NOT NULL,
                created_at TIMESTAMPTZ NOT NULL
            )
            """
        )
        conn.execute("ALTER TABLE admin_tokens ADD COLUMN IF NOT EXISTS token_type TEXT NOT NULL DEFAULT 'admin'")
        ensure_admin_settings(conn, utc_now_iso=utc_now_iso)
        if ADMIN_PANEL_USERNAME and ADMIN_PANEL_PASSWORD:
            ensure_admin_credentials(
                conn,
                username=ADMIN_PANEL_USERNAME,
                password=ADMIN_PANEL_PASSWORD,
                utc_now_iso=utc_now_iso,
            )
        if DEFAULT_WEB_USERNAME and DEFAULT_WEB_PASSWORD:
            ensure_default_web_user(
                conn,
                username=DEFAULT_WEB_USERNAME,
                password=DEFAULT_WEB_PASSWORD,
                utc_now_iso=utc_now_iso,
            )
        conn.commit()
    finally:
        conn.close()


def _retention_cutoff_iso() -> str:
    return (datetime.now(timezone.utc) - timedelta(days=RETENTION_DAYS)).isoformat()


def run_retention_cleanup() -> None:
    cutoff = _retention_cutoff_iso()
    conn = db_connect()
    try:
        conn.execute("DELETE FROM usage_sessions WHERE end_time < %s", (cutoff,))
        conn.execute("DELETE FROM data_usage_sessions WHERE end_time < %s", (cutoff,))
        conn.execute("DELETE FROM app_data_usage_sessions WHERE end_time < %s", (cutoff,))
        conn.execute(
            """
            DELETE FROM app_presence_periods
            WHERE removed_at IS NOT NULL
              AND removed_at < %s
            """,
            (cutoff,),
        )
        conn.commit()
    finally:
        conn.close()


def _retention_cleanup_loop() -> None:
    while not _retention_stop_event.is_set():
        try:
            run_retention_cleanup()
        except Exception as exc:
            print(f"Retention cleanup failed: {exc}")
        if _retention_stop_event.wait(RETENTION_CLEANUP_INTERVAL_SECONDS):
            return


def start_background_workers() -> None:
    global _retention_thread
    if _retention_thread and _retention_thread.is_alive():
        return
    _retention_stop_event.clear()
    _retention_thread = threading.Thread(
        target=_retention_cleanup_loop,
        name="usage-retention-cleanup",
        daemon=True,
    )
    _retention_thread.start()


def stop_background_workers() -> None:
    _retention_stop_event.set()
    if _retention_thread and _retention_thread.is_alive():
        _retention_thread.join(timeout=2)
    if _db_pool is not None:
        _db_pool.close_all()


class UsageHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 128


def _sync_apps_inventory(
    conn: psycopg.Connection,
    *,
    device_id: str,
    apps: list[dict[str, Any]],
    apps_full_replace: bool,
    apps_replace_complete: bool,
    inventory_sync_id: str | None,
    now: str,
) -> None:
    active_packages: set[str] = set()
    effective_sync_id = inventory_sync_id if apps_full_replace else None

    for app in apps:
        package_name = str(app.get("package_name", "")).strip()
        app_name = str(app.get("app_name", "")).strip()
        if not package_name or not app_name:
            raise ValueError("Each app must include package_name and app_name")
        icon_base64 = app.get("icon_base64")
        is_system = _coerce_bool(app.get("is_system", False))
        is_tracking = _coerce_bool(app.get("is_tracking", False))
        active_packages.add(package_name)
        conn.execute(
            """
            INSERT INTO apps(
              device_id, package_name, app_name, icon_base64, is_system, is_tracking, updated_at, inventory_sync_id
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (device_id, package_name) DO UPDATE SET
                app_name = excluded.app_name,
                icon_base64 = COALESCE(excluded.icon_base64, apps.icon_base64),
                is_system = excluded.is_system,
                is_tracking = excluded.is_tracking,
                updated_at = excluded.updated_at,
                inventory_sync_id = excluded.inventory_sync_id
            """,
            (
                device_id,
                package_name,
                app_name,
                icon_base64,
                is_system,
                is_tracking,
                now,
                effective_sync_id,
            ),
        )

        active_period = conn.execute(
            """
            SELECT id
            FROM app_presence_periods
            WHERE device_id = %s
              AND package_name = %s
              AND removed_at IS NULL
            ORDER BY installed_at DESC
            LIMIT 1
            """,
            (device_id, package_name),
        ).fetchone()
        if active_period:
            conn.execute(
                """
                UPDATE app_presence_periods
                SET app_name = %s,
                    icon_base64 = COALESCE(%s, icon_base64),
                    is_system = %s,
                    is_tracking = %s,
                    last_seen_at = %s
                WHERE id = %s
                """,
                (app_name, icon_base64, is_system, is_tracking, now, active_period["id"]),
            )
        else:
            conn.execute(
                """
                INSERT INTO app_presence_periods(
                  device_id, package_name, app_name, icon_base64, is_system, is_tracking, installed_at, last_seen_at, removed_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NULL)
                """,
                (device_id, package_name, app_name, icon_base64, is_system, is_tracking, now, now),
            )

    if apps_full_replace and apps_replace_complete and effective_sync_id:
        stale_rows = conn.execute(
            """
            SELECT package_name
            FROM apps
            WHERE device_id = %s
              AND COALESCE(inventory_sync_id, '') <> %s
            """,
            (device_id, effective_sync_id),
        ).fetchall()
        for stale in stale_rows:
            package_name = str(stale["package_name"])
            conn.execute(
                """
                UPDATE app_presence_periods
                SET removed_at = %s,
                    last_seen_at = %s
                WHERE id = (
                    SELECT id
                    FROM app_presence_periods
                    WHERE device_id = %s
                      AND package_name = %s
                      AND removed_at IS NULL
                    ORDER BY installed_at DESC
                    LIMIT 1
                )
                """,
                (now, now, device_id, package_name),
            )
        conn.execute(
            """
            DELETE FROM apps
            WHERE device_id = %s
              AND COALESCE(inventory_sync_id, '') <> %s
            """,
            (device_id, effective_sync_id),
        )


class ApiHandler(BaseHTTPRequestHandler):
    server_version = "UsageTracker/0.4"

    def _write_json(self, status: int, payload: Any) -> None:
        body = json.dumps(
            payload,
            default=_json_default,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body))) 
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        return json.loads(raw.decode("utf-8"))

    def _parse_and_validate_range(self, query: dict[str, list[str]]) -> tuple[str, str]:
        from_time = query.get("from", [None])[0]
        to_time = query.get("to", [None])[0]
        if not from_time or not to_time:
            raise ValueError("Query params 'from' and 'to' are required")
        from_iso = parse_iso8601(from_time)
        to_iso = parse_iso8601(to_time)
        from_dt = datetime.fromisoformat(from_iso)
        to_dt = datetime.fromisoformat(to_iso)
        if to_dt <= from_dt:
            raise ValueError("'to' must be later than 'from'")
        max_days = 62
        if (to_dt - from_dt).total_seconds() > max_days * 24 * 60 * 60:
            raise ValueError("Maximum range is 62 days")
        return from_iso, to_iso

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.end_headers()

    def _is_protected_route(self, method: str, path: str) -> bool:
        if path in ("/api/v1/health", "/api/v1/login", "/api/v1/admin/login"):
            return False
        if path in ("/api/v1/devices/register", "/api/v1/sync"):
            return False
        return path.startswith("/api/v1/")

    def _is_admin_only_route(self, method: str, path: str) -> bool:
        if path.startswith("/api/v1/admin/") and path != "/api/v1/admin/login":
            return True
        if path == "/api/v1/users":
            return True
        if path.startswith("/api/v1/users/"):
            return True
        return False

    def _get_authorized_token_type(self) -> str | None:
        return get_authorized_token_type(
            self.headers,
            db_connect=db_connect,
            utc_now_iso=utc_now_iso,
        )

    def _is_authorized(self) -> bool:
        return self._get_authorized_token_type() in ("user", "admin")

    def _is_admin_authorized(self) -> bool:
        return self._get_authorized_token_type() == "admin"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        try:
            if self._is_protected_route("GET", path) and not self._is_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if self._is_admin_only_route("GET", path) and not self._is_admin_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if path == "/api/v1/health":
                return self._write_json(200, {"ok": True, "time": utc_now_iso()})
            if path == "/api/v1/main-categories":
                return self._get_main_categories()
            if path == "/api/v1/sub-categories":
                return self._get_sub_categories(query)
            if path == "/api/v1/devices":
                return self._get_devices()
            if path == "/api/v1/export/usage":
                return self._get_usage_export(query)
            if path == "/api/v1/users":
                return self._get_web_users()
            if path.startswith("/api/v1/devices/") and path.endswith("/apps"):
                device_id = path.strip("/").split("/")[3]
                return self._get_device_apps(device_id, query)
            if path.startswith("/api/v1/devices/") and path.endswith("/screen-time"):
                device_id = path.strip("/").split("/")[3]
                return self._get_device_screen_time(device_id, query)
            if path.startswith("/api/v1/devices/") and path.endswith("/data-usage"):
                device_id = path.strip("/").split("/")[3]
                return self._get_device_data_usage(device_id, query)
            if path.startswith("/api/v1/devices/") and path.endswith("/data-usage-daily"):
                device_id = path.strip("/").split("/")[3]
                return self._get_device_data_usage_daily(device_id, query)
            return self._write_json(404, {"error": "Not found"})
        except ValueError as exc:
            return self._write_json(400, {"error": str(exc)})
        except Exception as exc:
            return self._write_json(500, {"error": f"Internal error: {exc}"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        try:
            if path == "/api/v1/login":
                return self._user_login(self._read_json())
            if path == "/api/v1/admin/login":
                return self._admin_login(self._read_json())
            if self._is_protected_route("POST", path) and not self._is_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if self._is_admin_only_route("POST", path) and not self._is_admin_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if path == "/api/v1/main-categories":
                return self._create_main_category(self._read_json())
            if path == "/api/v1/sub-categories":
                return self._create_sub_category(self._read_json())
            if path == "/api/v1/devices":
                return self._create_device(self._read_json())
            if path == "/api/v1/devices/unlink":
                return self._unlink_device(self._read_json())
            if path == "/api/v1/devices/register":
                return self._register_device(self._read_json())
            if path == "/api/v1/sync":
                return self._sync(self._read_json())
            if path == "/api/v1/users":
                return self._create_web_user(self._read_json())
            return self._write_json(404, {"error": "Not found"})
        except psycopg.Error as exc:
            if exc.sqlstate == "23505":
                return self._write_json(400, {"error": self._friendly_db_error(exc)})
            return self._write_json(500, {"error": f"DB error: {exc}"})
        except ValueError as exc:
            return self._write_json(400, {"error": str(exc)})
        except Exception as exc:
            return self._write_json(500, {"error": f"Internal error: {exc}"})

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        try:
            if self._is_protected_route("PUT", path) and not self._is_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if self._is_admin_only_route("PUT", path) and not self._is_admin_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if path.startswith("/api/v1/main-categories/"):
                category_id = int(path.rsplit("/", 1)[1])
                return self._update_main_category(category_id, self._read_json())
            if path.startswith("/api/v1/sub-categories/"):
                sub_id = int(path.rsplit("/", 1)[1])
                return self._update_sub_category(sub_id, self._read_json())
            if path.startswith("/api/v1/devices/"):
                device_id = path.rsplit("/", 1)[1]
                return self._update_device(device_id, self._read_json())
            if path.startswith("/api/v1/users/") and not path.endswith("/password"):
                username = path.split("/")[4]
                return self._update_web_user(username, self._read_json())
            if path.startswith("/api/v1/users/") and path.endswith("/password"):
                username = path.split("/")[4]
                return self._update_web_user_password(username, self._read_json())
            return self._write_json(404, {"error": "Not found"})
        except psycopg.Error as exc:
            if exc.sqlstate == "23505":
                return self._write_json(400, {"error": self._friendly_db_error(exc)})
            return self._write_json(500, {"error": f"DB error: {exc}"})
        except ValueError as exc:
            return self._write_json(400, {"error": str(exc)})
        except Exception as exc:
            return self._write_json(500, {"error": f"Internal error: {exc}"})

    def do_DELETE(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        try:
            if self._is_protected_route("DELETE", path) and not self._is_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if self._is_admin_only_route("DELETE", path) and not self._is_admin_authorized():
                return self._write_json(401, {"error": "Unauthorized"})
            if path.startswith("/api/v1/main-categories/"):
                category_id = int(path.rsplit("/", 1)[1])
                return self._delete_main_category(category_id)
            if path.startswith("/api/v1/sub-categories/"):
                sub_id = int(path.rsplit("/", 1)[1])
                return self._delete_sub_category(sub_id)
            if path.startswith("/api/v1/users/"):
                username = path.split("/")[4]
                return self._delete_web_user(username)
            if path.startswith("/api/v1/devices/"):
                device_id = path.rsplit("/", 1)[1]
                return self._delete_device(device_id)
            return self._write_json(404, {"error": "Not found"})
        except ValueError as exc:
            return self._write_json(400, {"error": str(exc)})
        except Exception as exc:
            return self._write_json(500, {"error": f"Internal error: {exc}"})

    def _admin_login(self, data: dict[str, Any]) -> None:
        return handle_admin_login(
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            admin_token_hours=ADMIN_TOKEN_HOURS,
            utc_now_iso=utc_now_iso,
        )

    def _user_login(self, data: dict[str, Any]) -> None:
        return handle_user_login(
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            admin_token_hours=ADMIN_TOKEN_HOURS,
            utc_now_iso=utc_now_iso,
        )

    def _friendly_db_error(self, exc: psycopg.Error) -> str:
        constraint = getattr(getattr(exc, "diag", None), "constraint_name", None)
        if constraint == "uq_main_categories_name":
            return "Main category already exists"
        if constraint == "uq_sub_categories_main_name":
            return "Sub category already exists for this main category"
        if constraint == "devices_pkey":
            return "Device ID already exists"
        return "Already exists"

    def _admin_set_credentials(self, data: dict[str, Any]) -> None:
        return handle_admin_set_credentials(
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            utc_now_iso=utc_now_iso,
            is_admin_authorized=self._is_admin_authorized,
        )

    def _get_web_users(self) -> None:
        return handle_get_web_users(write_json=self._write_json, db_connect=db_connect)

    def _create_web_user(self, data: dict[str, Any]) -> None:
        return handle_create_web_user(
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            utc_now_iso=utc_now_iso,
        )

    def _update_web_user_password(self, username: str, data: dict[str, Any]) -> None:
        return handle_update_web_user_password(
            username,
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            utc_now_iso=utc_now_iso,
        )

    def _update_web_user(self, username: str, data: dict[str, Any]) -> None:
        return handle_update_web_user(
            username,
            data,
            write_json=self._write_json,
            db_connect=db_connect,
            utc_now_iso=utc_now_iso,
        )

    def _delete_web_user(self, username: str) -> None:
        return handle_delete_web_user(
            username,
            write_json=self._write_json,
            db_connect=db_connect,
        )

    def _get_main_categories(self) -> None:
        conn = db_connect()
        try:
            rows = conn.execute(
                "SELECT id, name, created_at FROM main_categories ORDER BY name ASC"
            ).fetchall()
            return self._write_json(200, {"main_categories": [dict(r) for r in rows]})
        finally:
            conn.close()

    def _create_main_category(self, data: dict[str, Any]) -> None:
        name = str(data.get("name", "")).strip()
        if not name:
            raise ValueError("Missing required field: name")
        conn = db_connect()
        try:
            cur = conn.execute(
                "INSERT INTO main_categories(name, created_at) VALUES (%s, %s) RETURNING id",
                (name, utc_now_iso()),
            )
            row = cur.fetchone()
            conn.commit()
            return self._write_json(200, {"ok": True, "id": row["id"] if row else None})
        finally:
            conn.close()

    def _update_main_category(self, category_id: int, data: dict[str, Any]) -> None:
        name = str(data.get("name", "")).strip()
        if not name:
            raise ValueError("Missing required field: name")
        conn = db_connect()
        try:
            cur = conn.execute(
                "UPDATE main_categories SET name = %s WHERE id = %s",
                (name, category_id),
            )
            conn.commit()
            if cur.rowcount == 0:
                raise ValueError("Main category not found")
            return self._write_json(200, {"ok": True})
        finally:
            conn.close()

    def _delete_main_category(self, category_id: int) -> None:
        conn = db_connect()
        try:
            cur = conn.execute("DELETE FROM main_categories WHERE id = %s", (category_id,))
            conn.commit()
            if cur.rowcount == 0:
                raise ValueError("Main category not found")
            return self._write_json(200, {"ok": True})
        finally:
            conn.close()

    def _get_sub_categories(self, query: dict[str, list[str]]) -> None:
        main_category_id = query.get("main_category_id", [None])[0]
        conn = db_connect()
        try:
            if main_category_id:
                rows = conn.execute(
                    """
                    SELECT sc.id, sc.name, sc.main_category_id, mc.name AS main_category_name, sc.created_at
                    FROM sub_categories sc
                    JOIN main_categories mc ON mc.id = sc.main_category_id
                    WHERE sc.main_category_id = %s
                    ORDER BY sc.name ASC
                    """,
                    (int(main_category_id),),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT sc.id, sc.name, sc.main_category_id, mc.name AS main_category_name, sc.created_at
                    FROM sub_categories sc
                    JOIN main_categories mc ON mc.id = sc.main_category_id
                    ORDER BY mc.name ASC, sc.name ASC
                    """
                ).fetchall()
            return self._write_json(200, {"sub_categories": [dict(r) for r in rows]})
        finally:
            conn.close()

    def _create_sub_category(self, data: dict[str, Any]) -> None:
        name = str(data.get("name", "")).strip()
        main_category_id = int(data.get("main_category_id", 0))
        if not name or main_category_id <= 0:
            raise ValueError("Missing required fields: name, main_category_id")
        conn = db_connect()
        try:
            cur = conn.execute(
                """
                INSERT INTO sub_categories(main_category_id, name, created_at)
                VALUES (%s, %s, %s)
                RETURNING id
                """,
                (main_category_id, name, utc_now_iso()),
            )
            row = cur.fetchone()
            conn.commit()
            return self._write_json(200, {"ok": True, "id": row["id"] if row else None})
        finally:
            conn.close()

    def _update_sub_category(self, sub_id: int, data: dict[str, Any]) -> None:
        name = str(data.get("name", "")).strip()
        main_category_id = int(data.get("main_category_id", 0))
        if not name or main_category_id <= 0:
            raise ValueError("Missing required fields: name, main_category_id")
        conn = db_connect()
        try:
            cur = conn.execute(
                """
                UPDATE sub_categories
                SET name = %s, main_category_id = %s
                WHERE id = %s
                """,
                (name, main_category_id, sub_id),
            )
            conn.commit()
            if cur.rowcount == 0:
                raise ValueError("Sub category not found")
            return self._write_json(200, {"ok": True})
        finally:
            conn.close()

    def _delete_sub_category(self, sub_id: int) -> None:
        conn = db_connect()
        try:
            cur = conn.execute("DELETE FROM sub_categories WHERE id = %s", (sub_id,))
            conn.commit()
            if cur.rowcount == 0:
                raise ValueError("Sub category not found")
            return self._write_json(200, {"ok": True})
        finally:
            conn.close()

    def _validate_sub_belongs_main(
        self, conn: psycopg.Connection, main_category_id: int, sub_category_id: int
    ) -> None:
        row = conn.execute(
            "SELECT id FROM sub_categories WHERE id = %s AND main_category_id = %s",
            (sub_category_id, main_category_id),
        ).fetchone()
        if not row:
            raise ValueError("Sub category does not belong to selected main category")

    def _create_device(self, data: dict[str, Any]) -> None:
        device_id = str(data.get("device_id", "")).strip().upper()
        main_category_id = int(data.get("main_category_id", 0))
        sub_category_id = int(data.get("sub_category_id", 0))
        if not device_id or main_category_id <= 0 or sub_category_id <= 0:
            raise ValueError("Missing required fields: device_id, main_category_id, sub_category_id")
        now = utc_now_iso()
        conn = db_connect()
        try:
            self._validate_sub_belongs_main(conn, main_category_id, sub_category_id)
            existing = conn.execute(
                "SELECT device_id, status, bound_client_id FROM devices WHERE device_id = %s",
                (device_id,),
            ).fetchone()
            if existing and existing["status"] == "active":
                raise ValueError("Device ID already exists")
            if existing and existing["status"] != "active":
                if existing["bound_client_id"]:
                    conn.execute(
                        """
                        INSERT INTO device_tombstones(device_id, blocked_client_id, created_at)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (device_id, blocked_client_id) DO NOTHING
                        """,
                        (device_id, existing["bound_client_id"], now),
                    )
                conn.execute(
                    """
                    UPDATE devices
                    SET main_category_id = %s, sub_category_id = %s, status = 'active',
                        bound_client_id = NULL, bound_at = NULL, updated_at = %s
                    WHERE device_id = %s
                    """,
                    (main_category_id, sub_category_id, now, device_id),
                )
                conn.execute("DELETE FROM apps WHERE device_id = %s", (device_id,))
                conn.execute("DELETE FROM usage_sessions WHERE device_id = %s", (device_id,))
                conn.execute(
                    "DELETE FROM data_usage_sessions WHERE device_id = %s",
                    (device_id,),
                )
            else:
                conn.execute(
                    """
                    INSERT INTO devices(
                      device_id, main_category_id, sub_category_id, status, created_at, updated_at
                    ) VALUES (%s, %s, %s, 'active', %s, %s)
                    """,
                    (device_id, main_category_id, sub_category_id, now, now),
                )
            conn.commit()
            return self._write_json(200, {"ok": True, "device_id": device_id})
        finally:
            conn.close()

    def _update_device(self, current_device_id: str, data: dict[str, Any]) -> None:
        new_device_id = str(data.get("device_id", current_device_id)).strip().upper()
        main_category_id = int(data.get("main_category_id", 0))
        sub_category_id = int(data.get("sub_category_id", 0))
        if not new_device_id or main_category_id <= 0 or sub_category_id <= 0:
            raise ValueError("Missing required fields: device_id, main_category_id, sub_category_id")
        now = utc_now_iso()
        conn = db_connect()
        try:
            self._validate_sub_belongs_main(conn, main_category_id, sub_category_id)
            existing = conn.execute(
                "SELECT bound_client_id, status FROM devices WHERE device_id = %s",
                (current_device_id,),
            ).fetchone()
            if not existing:
                raise ValueError("Device not found")
            if existing["status"] != "active":
                raise ValueError("Device is not active")

            if new_device_id != current_device_id:
                conflict = conn.execute(
                    "SELECT device_id FROM devices WHERE device_id = %s",
                    (new_device_id,),
                ).fetchone()
                if conflict:
                    raise ValueError("Device ID already exists")
                conn.execute(
                    "UPDATE devices SET device_id = %s WHERE device_id = %s",
                    (new_device_id, current_device_id),
                )
                conn.execute(
                    "UPDATE apps SET device_id = %s WHERE device_id = %s",
                    (new_device_id, current_device_id),
                )
                conn.execute(
                    "UPDATE usage_sessions SET device_id = %s WHERE device_id = %s",
                    (new_device_id, current_device_id),
                )
                conn.execute(
                    "UPDATE data_usage_sessions SET device_id = %s WHERE device_id = %s",
                    (new_device_id, current_device_id),
                )
                if existing["bound_client_id"]:
                    conn.execute(
                        """
                        INSERT INTO device_tombstones(device_id, blocked_client_id, created_at)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (device_id, blocked_client_id) DO NOTHING
                        """,
                        (new_device_id, existing["bound_client_id"], now),
                    )
                conn.execute(
                    """
                    UPDATE devices
                    SET bound_client_id = NULL, bound_at = NULL
                    WHERE device_id = %s
                    """,
                    (new_device_id,),
                )
            conn.execute(
                """
                UPDATE devices
                SET main_category_id = %s, sub_category_id = %s, updated_at = %s
                WHERE device_id = %s
                """,
                (main_category_id, sub_category_id, now, new_device_id),
            )
            conn.commit()
            return self._write_json(200, {"ok": True, "device_id": new_device_id})
        finally:
            conn.close()

    def _delete_device(self, device_id: str) -> None:
        conn = db_connect()
        try:
            row = conn.execute(
                "SELECT device_id FROM devices WHERE device_id = %s",
                (device_id,),
            ).fetchone()
            if not row:
                raise ValueError("Device not found")
            conn.execute("DELETE FROM device_tombstones WHERE device_id = %s", (device_id,))
            conn.execute("DELETE FROM devices WHERE device_id = %s", (device_id,))
            conn.commit()
            return self._write_json(200, {"ok": True, "deleted": "hard"})
        finally:
            conn.close()

    def _get_devices(self) -> None:
        conn = db_connect()
        try:
            rows = conn.execute(
                """
                SELECT
                    d.device_id,
                    d.display_name,
                    d.status,
                    d.last_seen_at,
                    d.main_category_id,
                    mc.name AS main_category_name,
                    d.sub_category_id,
                    sc.name AS sub_category_name,
                    CASE
                      WHEN d.bound_client_id IS NULL THEN FALSE
                      ELSE TRUE
                    END AS is_connected,
                    COALESCE(
                        SUM(
                            LEAST(
                                u.foreground_ms,
                                GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                            )
                        ),
                        0
                    )::bigint AS total_foreground_ms
                FROM devices d
                LEFT JOIN main_categories mc ON mc.id = d.main_category_id
                LEFT JOIN sub_categories sc ON sc.id = d.sub_category_id
                LEFT JOIN usage_sessions u ON u.device_id = d.device_id
                  AND u.end_time >= (NOW() AT TIME ZONE 'UTC') - interval '62 days'
                WHERE d.status = 'active'
                GROUP BY
                    d.device_id,
                    d.display_name,
                    d.status,
                    d.last_seen_at,
                    d.main_category_id,
                    mc.name,
                    d.sub_category_id,
                    sc.name,
                    d.bound_client_id
                ORDER BY mc.name ASC, sc.name ASC, d.device_id ASC
                """
            ).fetchall()
            return self._write_json(200, {"devices": [dict(r) for r in rows]})
        finally:
            conn.close()

    def _get_usage_export(self, query: dict[str, list[str]]) -> None:
        from_iso, to_iso = self._parse_and_validate_range(query)
        main_category_id = int(query.get("main_category_id", ["0"])[0] or "0")
        sub_category_id = int(query.get("sub_category_id", ["0"])[0] or "0")
        if main_category_id <= 0 or sub_category_id <= 0:
            raise ValueError("Query params 'main_category_id' and 'sub_category_id' are required")
        conn = db_connect()
        try:
            self._validate_sub_belongs_main(conn, main_category_id, sub_category_id)
            category_row = conn.execute(
                """
                SELECT
                    mc.id AS main_category_id,
                    mc.name AS main_category_name,
                    sc.id AS sub_category_id,
                    sc.name AS sub_category_name
                FROM main_categories mc
                JOIN sub_categories sc ON sc.main_category_id = mc.id
                WHERE mc.id = %s AND sc.id = %s
                """,
                (main_category_id, sub_category_id),
            ).fetchone()
            if not category_row:
                raise ValueError("Selected faculty or year intake was not found")

            device_rows = conn.execute(
                """
                WITH selected_devices AS (
                    SELECT
                        d.device_id,
                        d.display_name,
                        d.last_seen_at
                    FROM devices d
                    WHERE d.status = 'active'
                      AND d.main_category_id = %s
                      AND d.sub_category_id = %s
                ),
                range_bounds AS (
                    SELECT %s::timestamptz AS from_ts, %s::timestamptz AS to_ts
                ),
                usage_weighted AS (
                    SELECT
                        u.device_id,
                        CASE
                            WHEN EXTRACT(EPOCH FROM (u.end_time - u.start_time)) <= 0 THEN 0.0
                            ELSE
                                LEAST(
                                    u.foreground_ms,
                                    GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                                ) * (
                                    EXTRACT(EPOCH FROM (
                                        LEAST(u.end_time, rb.to_ts) - GREATEST(u.start_time, rb.from_ts)
                                    )) / EXTRACT(EPOCH FROM (u.end_time - u.start_time))
                                )
                        END AS weighted_ms
                    FROM usage_sessions u
                    CROSS JOIN range_bounds rb
                    JOIN selected_devices sd ON sd.device_id = u.device_id
                    WHERE u.end_time > rb.from_ts
                      AND u.start_time < rb.to_ts
                )
                SELECT
                    sd.device_id,
                    sd.display_name,
                    sd.last_seen_at,
                    COALESCE(ROUND(SUM(uw.weighted_ms)), 0)::bigint AS total_foreground_ms
                FROM selected_devices sd
                LEFT JOIN usage_weighted uw ON uw.device_id = sd.device_id
                GROUP BY sd.device_id, sd.display_name, sd.last_seen_at
                ORDER BY sd.device_id ASC
                """,
                (main_category_id, sub_category_id, from_iso, to_iso),
            ).fetchall()

            app_rows = conn.execute(
                """
                WITH selected_devices AS (
                    SELECT d.device_id
                    FROM devices d
                    WHERE d.status = 'active'
                      AND d.main_category_id = %s
                      AND d.sub_category_id = %s
                ),
                range_bounds AS (
                    SELECT %s::timestamptz AS from_ts, %s::timestamptz AS to_ts
                ),
                presence_rows AS (
                    SELECT
                        ap.device_id,
                        ap.package_name,
                        ap.app_name,
                        ap.is_system,
                        ap.is_tracking,
                        ap.last_seen_at,
                        ap.removed_at,
                        CASE
                            WHEN ap.installed_at < rb.to_ts
                             AND COALESCE(ap.removed_at, 'infinity'::timestamptz) > rb.from_ts
                            THEN 1 ELSE 0
                        END AS range_overlap_flag
                    FROM app_presence_periods ap
                    CROSS JOIN range_bounds rb
                    JOIN selected_devices sd ON sd.device_id = ap.device_id
                ),
                app_meta AS (
                    SELECT DISTINCT ON (device_id, package_name)
                        device_id,
                        package_name,
                        app_name,
                        is_system,
                        is_tracking
                    FROM (
                        SELECT
                            device_id,
                            package_name,
                            app_name,
                            is_system,
                            is_tracking,
                            range_overlap_flag,
                            COALESCE(removed_at, 'infinity'::timestamptz) AS sort_removed_at,
                            last_seen_at
                        FROM presence_rows
                        UNION ALL
                        SELECT
                            a.device_id,
                            a.package_name,
                            a.app_name,
                            a.is_system,
                            a.is_tracking,
                            0 AS range_overlap_flag,
                            'infinity'::timestamptz AS sort_removed_at,
                            a.updated_at AS last_seen_at
                        FROM apps a
                        JOIN selected_devices sd ON sd.device_id = a.device_id
                    ) ranked
                    ORDER BY device_id, package_name, range_overlap_flag DESC, sort_removed_at DESC, last_seen_at DESC
                ),
                usage_weighted AS (
                    SELECT
                        u.device_id,
                        u.package_name,
                        CASE
                            WHEN EXTRACT(EPOCH FROM (u.end_time - u.start_time)) <= 0 THEN 0.0
                            ELSE
                                LEAST(
                                    u.foreground_ms,
                                    GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                                ) * (
                                    EXTRACT(EPOCH FROM (
                                        LEAST(u.end_time, rb.to_ts) - GREATEST(u.start_time, rb.from_ts)
                                    )) / EXTRACT(EPOCH FROM (u.end_time - u.start_time))
                                )
                        END AS weighted_ms
                    FROM usage_sessions u
                    CROSS JOIN range_bounds rb
                    JOIN selected_devices sd ON sd.device_id = u.device_id
                    WHERE u.end_time > rb.from_ts
                      AND u.start_time < rb.to_ts
                ),
                app_totals AS (
                    SELECT
                        uw.device_id,
                        uw.package_name,
                        COALESCE(ROUND(SUM(uw.weighted_ms)), 0)::bigint AS total_foreground_ms
                    FROM usage_weighted uw
                    GROUP BY uw.device_id, uw.package_name
                )
                SELECT
                    at.device_id,
                    at.package_name,
                    COALESCE(am.app_name, at.package_name) AS app_name,
                    COALESCE(am.is_system, FALSE) AS raw_is_system,
                    COALESCE(am.is_tracking, FALSE) AS raw_is_tracking,
                    at.total_foreground_ms
                FROM app_totals at
                LEFT JOIN app_meta am
                  ON am.device_id = at.device_id
                 AND am.package_name = at.package_name
                WHERE at.total_foreground_ms > 0
                ORDER BY at.device_id ASC, at.total_foreground_ms DESC, COALESCE(am.app_name, at.package_name) ASC
                """,
                (main_category_id, sub_category_id, from_iso, to_iso),
            ).fetchall()

            apps_by_device: dict[str, list[dict[str, Any]]] = {}
            non_system_totals_by_device: dict[str, int] = {}
            for row in app_rows:
                total_ms = int(row["total_foreground_ms"] or 0)
                if _coerce_bool(row.get("raw_is_tracking", False)):
                    continue
                is_system = _classify_is_system(
                    row.get("package_name", ""),
                    row.get("app_name", ""),
                    row.get("raw_is_system", False),
                )
                if is_system:
                    continue
                non_system_totals_by_device[row["device_id"]] = (
                    non_system_totals_by_device.get(row["device_id"], 0) + total_ms
                )
                if total_ms < 60_000:
                    continue
                apps_by_device.setdefault(row["device_id"], []).append(
                    {
                        "package_name": row["package_name"],
                        "app_name": row["app_name"],
                        "total_foreground_ms": total_ms,
                    }
                )

            export_rows = []
            for row in device_rows:
                export_rows.append(
                    {
                        "device_id": row["device_id"],
                        "display_name": row["display_name"],
                        "last_seen_at": row["last_seen_at"],
                        "total_foreground_ms": non_system_totals_by_device.get(row["device_id"], 0),
                        "most_used_apps": apps_by_device.get(row["device_id"], []),
                    }
                )

            title = (
                f"Device usage between {from_iso} and {to_iso} "
                f"for {category_row['main_category_name']} Year {category_row['sub_category_name']}"
            )
            return self._write_json(
                200,
                {
                    "title": title,
                    "from": from_iso,
                    "to": to_iso,
                    "main_category_id": category_row["main_category_id"],
                    "main_category_name": category_row["main_category_name"],
                    "sub_category_id": category_row["sub_category_id"],
                    "sub_category_name": category_row["sub_category_name"],
                    "devices": export_rows,
                },
            )
        finally:
            conn.close()

    def _register_device(self, data: dict[str, Any]) -> None:
        device_id = str(data.get("device_id", "")).strip().upper()
        client_instance_id = str(data.get("client_instance_id", "")).strip()
        device_token = str(data.get("device_token", "")).strip() or None
        display_name = str(data.get("display_name", "")).strip() or None
        if not device_id or not client_instance_id:
            raise ValueError("Missing required fields: device_id, client_instance_id")
        now = utc_now_iso()
        conn = db_connect()
        try:
            row = conn.execute(
                """
                SELECT status, bound_client_id, device_token
                FROM devices
                WHERE device_id = %s
                """,
                (device_id,),
            ).fetchone()
            if not row or row["status"] != "active":
                raise ValueError("Unknown or inactive device ID")

            blocked = conn.execute(
                """
                SELECT id FROM device_tombstones
                WHERE device_id = %s AND blocked_client_id = %s
                """,
                (device_id, client_instance_id),
            ).fetchone()
            if blocked:
                raise ValueError("This device installation is blocked for this device ID")

            bound = row["bound_client_id"]
            if bound and bound != client_instance_id:
                stored_token = row.get("device_token")
                if device_token and stored_token and stored_token == device_token:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s,
                            display_name = COALESCE(%s, display_name),
                            last_seen_at = %s, updated_at = %s,
                            device_token = COALESCE(device_token, %s)
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, display_name, now, now, device_token, device_id),
                    )
                    conn.commit()
                    return self._write_json(200, {"ok": True, "device_id": device_id})
                if device_token and not stored_token:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s,
                            display_name = COALESCE(%s, display_name),
                            last_seen_at = %s, updated_at = %s,
                            device_token = %s
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, display_name, now, now, device_token, device_id),
                    )
                    conn.commit()
                    return self._write_json(200, {"ok": True, "device_id": device_id})
                if device_token and stored_token and stored_token == bound:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s,
                            display_name = COALESCE(%s, display_name),
                            last_seen_at = %s, updated_at = %s,
                            device_token = %s
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, display_name, now, now, device_token, device_id),
                    )
                    conn.commit()
                    return self._write_json(200, {"ok": True, "device_id": device_id})
                raise ValueError("Device ID already linked to another physical device")

            if not bound:
                conn.execute(
                    """
                    UPDATE devices
                    SET bound_client_id = %s, bound_at = %s, display_name = COALESCE(%s, display_name),
                        last_seen_at = %s, updated_at = %s,
                        device_token = COALESCE(%s, device_token)
                    WHERE device_id = %s
                    """,
                    (client_instance_id, now, display_name, now, now, device_token, device_id),
                )
            else:
                conn.execute(
                    """
                    UPDATE devices
                    SET display_name = COALESCE(%s, display_name), last_seen_at = %s, updated_at = %s,
                        device_token = COALESCE(%s, device_token)
                    WHERE device_id = %s
                    """,
                    (display_name, now, now, device_token, device_id),
                )
            conn.commit()
            return self._write_json(200, {"ok": True, "device_id": device_id})
        finally:
            conn.close()

    def _unlink_device(self, data: dict[str, Any]) -> None:
        device_id = str(data.get("device_id", "")).strip().upper()
        client_instance_id = str(data.get("client_instance_id", "")).strip()
        device_token = str(data.get("device_token", "")).strip() or None
        if not device_id:
            raise ValueError("Missing required fields: device_id")
        now = utc_now_iso()
        conn = db_connect()
        try:
            row = conn.execute(
                """
                SELECT status, bound_client_id, device_token
                FROM devices
                WHERE device_id = %s
                """,
                (device_id,),
            ).fetchone()
            if not row or row["status"] != "active":
                raise ValueError("Unknown or inactive device ID")
            stored_token = row.get("device_token")
            bound = row.get("bound_client_id")
            is_match = False
            if device_token and stored_token and device_token == stored_token:
                is_match = True
            if client_instance_id and bound and client_instance_id == bound:
                is_match = True
            if not is_match:
                raise ValueError("Device ID is not linked to this physical device")

            conn.execute(
                """
                UPDATE devices
                SET bound_client_id = NULL,
                    device_token = NULL,
                    bound_at = NULL,
                    updated_at = %s
                WHERE device_id = %s
                """,
                (now, device_id),
            )
            conn.commit()
            return self._write_json(200, {"ok": True, "device_id": device_id})
        finally:
            conn.close()

    def _sync(self, data: dict[str, Any]) -> None:
        required = ("device_id", "client_instance_id", "apps", "usage_sessions")
        for key in required:
            if key not in data:
                raise ValueError(f"Missing required field: {key}")
        device_id = str(data["device_id"]).strip().upper()
        client_instance_id = str(data["client_instance_id"]).strip()
        device_token = str(data.get("device_token", "")).strip() or None
        apps = data["apps"]
        apps_full_replace = bool(data.get("apps_full_replace", False))
        apps_append = bool(data.get("apps_append", False))
        apps_replace_complete = bool(data.get("apps_replace_complete", False))
        inventory_sync_id = str(data.get("apps_inventory_sync_id", "")).strip() or None
        usage_sessions = data["usage_sessions"]
        now = utc_now_iso()
        if not isinstance(apps, list) or not isinstance(usage_sessions, list):
            raise ValueError("'apps' and 'usage_sessions' must be arrays")
        conn = db_connect()
        try:
            row = conn.execute(
                "SELECT status, bound_client_id, device_token FROM devices WHERE device_id = %s",
                (device_id,),
            ).fetchone()
            if not row or row["status"] != "active":
                raise ValueError("Unknown or inactive device ID")
            if row["bound_client_id"] != client_instance_id:
                stored_token = row.get("device_token")
                if device_token and stored_token and stored_token == device_token:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s, updated_at = %s
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, now, device_id),
                    )
                elif device_token and not stored_token:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s, updated_at = %s,
                            device_token = %s
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, now, device_token, device_id),
                    )
                elif device_token and stored_token and stored_token == row["bound_client_id"]:
                    conn.execute(
                        """
                        UPDATE devices
                        SET bound_client_id = %s, bound_at = %s, updated_at = %s,
                            device_token = %s
                        WHERE device_id = %s
                        """,
                        (client_instance_id, now, now, device_token, device_id),
                    )
                else:
                    raise ValueError("Device ID is not linked to this physical device")

            _sync_apps_inventory(
                conn,
                device_id=device_id,
                apps=apps,
                apps_full_replace=apps_full_replace,
                apps_replace_complete=apps_replace_complete,
                inventory_sync_id=inventory_sync_id,
                now=now,
            )

            inserted = 0
            cleaned_days: set[tuple[str, str]] = set()
            for row_data in usage_sessions:
                package_name = str(row_data.get("package_name", "")).strip()
                start_time = parse_iso8601(str(row_data.get("start_time", "")).strip())
                end_time = parse_iso8601(str(row_data.get("end_time", "")).strip())
                foreground_ms = int(row_data.get("foreground_ms", 0))
                if not package_name:
                    raise ValueError("Each usage session must include package_name")
                if foreground_ms < 0:
                    raise ValueError("foreground_ms cannot be negative")
                start_dt = datetime.fromisoformat(start_time)
                tk_dt = start_dt + timedelta(hours=5)
                day_start_tk = datetime(tk_dt.year, tk_dt.month, tk_dt.day, tzinfo=timezone.utc)
                day_start_utc = day_start_tk - timedelta(hours=5)
                day_end_utc = day_start_utc + timedelta(days=1)
                day_key = (package_name, day_start_utc.isoformat())
                if day_key not in cleaned_days:
                    conn.execute(
                        """
                        DELETE FROM usage_sessions
                        WHERE device_id = %s
                          AND package_name = %s
                          AND start_time >= %s
                          AND start_time < %s
                        """,
                        (device_id, package_name, day_start_utc.isoformat(), day_end_utc.isoformat()),
                    )
                    cleaned_days.add(day_key)
                cur = conn.execute(
                    """
                    INSERT INTO usage_sessions(
                      device_id, package_name, start_time, end_time, foreground_ms, synced_at
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (device_id, package_name, start_time) DO UPDATE SET
                        end_time = excluded.end_time,
                        foreground_ms = excluded.foreground_ms,
                        synced_at = excluded.synced_at
                    """,
                    (device_id, package_name, start_time, end_time, foreground_ms, now),
                )
                inserted += cur.rowcount

            conn.execute(
                "UPDATE devices SET last_seen_at = %s, updated_at = %s WHERE device_id = %s",
                (now, now, device_id),
            )
            conn.commit()
            return self._write_json(
                200,
                {
                    "ok": True,
                    "inserted_sessions": inserted,
                },
            )
        finally:
            conn.close()

    def _get_device_apps(self, device_id: str, query: dict[str, list[str]]) -> None:
        from_iso, to_iso = self._parse_and_validate_range(query)
        conn = db_connect()
        try:
            rows = conn.execute(
                """
                WITH range_bounds AS (
                    SELECT %s::timestamptz AS from_ts, %s::timestamptz AS to_ts
                ),
                presence_rows AS (
                    SELECT
                        ap.package_name,
                        ap.app_name,
                        ap.icon_base64,
                        ap.is_system,
                        ap.is_tracking,
                        ap.installed_at,
                        ap.last_seen_at,
                        ap.removed_at,
                        CASE
                            WHEN ap.installed_at < rb.to_ts
                             AND COALESCE(ap.removed_at, 'infinity'::timestamptz) > rb.from_ts
                            THEN 1 ELSE 0
                        END AS range_overlap_flag
                    FROM app_presence_periods ap
                    CROSS JOIN range_bounds rb
                    WHERE ap.device_id = %s
                ),
                app_meta AS (
                    SELECT DISTINCT ON (package_name)
                        package_name,
                        app_name,
                        icon_base64,
                        is_system,
                        is_tracking
                    FROM (
                        SELECT
                            package_name,
                            app_name,
                            icon_base64,
                            is_system,
                            is_tracking,
                            range_overlap_flag,
                            COALESCE(removed_at, 'infinity'::timestamptz) AS sort_removed_at,
                            last_seen_at
                        FROM presence_rows
                        UNION ALL
                        SELECT
                            a.package_name,
                            a.app_name,
                            a.icon_base64,
                            a.is_system,
                            a.is_tracking,
                            0 AS range_overlap_flag,
                            'infinity'::timestamptz AS sort_removed_at,
                            a.updated_at AS last_seen_at
                        FROM apps a
                        WHERE a.device_id = %s
                    ) ranked
                    ORDER BY package_name, range_overlap_flag DESC, sort_removed_at DESC, last_seen_at DESC
                ),
                packages AS (
                    SELECT package_name
                    FROM presence_rows
                    WHERE range_overlap_flag = 1
                    UNION
                    SELECT package_name
                    FROM usage_sessions
                    WHERE device_id = %s
                      AND end_time > %s
                      AND start_time < %s
                ),
                usage_weighted AS (
                    SELECT
                        u.package_name,
                        LEAST(
                            u.foreground_ms,
                            GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                        ) AS effective_ms,
                        CASE
                            WHEN EXTRACT(EPOCH FROM (u.end_time - u.start_time)) <= 0 THEN 0.0
                            ELSE
                                LEAST(
                                    u.foreground_ms,
                                    GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                                ) * (
                                    EXTRACT(EPOCH FROM (LEAST(u.end_time, rb.to_ts)
                                        - GREATEST(u.start_time, rb.from_ts)))
                                    / EXTRACT(EPOCH FROM (u.end_time - u.start_time))
                                )
                        END AS weighted_ms
                    FROM usage_sessions u
                    CROSS JOIN range_bounds rb
                    WHERE u.device_id = %s
                      AND u.end_time > %s
                      AND u.start_time < %s
                )
                SELECT
                    p.package_name,
                    COALESCE(am.app_name, p.package_name) AS app_name,
                    am.icon_base64,
                    COALESCE(am.is_system, FALSE) AS is_system,
                    COALESCE(am.is_tracking, FALSE) AS is_tracking,
                    COALESCE(ROUND(SUM(uw.weighted_ms)), 0)::bigint AS total_foreground_ms,
                    0::bigint AS total_data_bytes
                FROM packages p
                LEFT JOIN app_meta am
                    ON am.package_name = p.package_name
                LEFT JOIN usage_weighted uw
                    ON uw.package_name = p.package_name
                GROUP BY p.package_name, am.app_name, am.icon_base64, am.is_system, am.is_tracking
                ORDER BY total_foreground_ms DESC, COALESCE(am.app_name, p.package_name) ASC
                """,
                  (
                      from_iso,
                      to_iso,
                      device_id.upper(),
                      device_id.upper(),
                    device_id.upper(),
                    from_iso,
                    to_iso,
                    device_id.upper(),
                    from_iso,
                      to_iso,
                  ),
              ).fetchall()
            apps_payload = []
            for row in rows:
                item = dict(row)
                item["is_system"] = _classify_is_system(
                    item.get("package_name", ""),
                    item.get("app_name", ""),
                    item.get("is_system", False),
                )
                apps_payload.append(item)
            return self._write_json(
                200,
                {"device_id": device_id.upper(), "from": from_iso, "to": to_iso, "apps": apps_payload},
            )
        finally:
            conn.close()

    def _get_device_screen_time(self, device_id: str, query: dict[str, list[str]]) -> None:
        from_iso, to_iso = self._parse_and_validate_range(query)
        include_system = _parse_include_system(query)
        conn = db_connect()
        try:
            rows = conn.execute(
                """
                WITH RECURSIVE
                range_bounds AS (
                    SELECT
                        %s::timestamptz AS from_ts,
                        %s::timestamptz AS to_ts,
                        (date_trunc('day', %s::timestamptz + interval '5 hours'))::date AS from_day_tk,
                        (date_trunc('day', %s::timestamptz + interval '5 hours'))::date AS to_day_tk
                ),
                presence_rows AS (
                    SELECT
                        ap.package_name,
                        ap.app_name,
                        ap.icon_base64,
                        ap.is_system,
                        ap.is_tracking,
                        ap.installed_at,
                        ap.last_seen_at,
                        ap.removed_at,
                        CASE
                            WHEN ap.installed_at < rb.to_ts
                             AND COALESCE(ap.removed_at, 'infinity'::timestamptz) > rb.from_ts
                            THEN 1 ELSE 0
                        END AS range_overlap_flag
                    FROM app_presence_periods ap
                    CROSS JOIN range_bounds rb
                    WHERE ap.device_id = %s
                ),
                  app_meta AS (
                      SELECT DISTINCT ON (package_name)
                          package_name,
                          app_name,
                          is_system,
                          is_tracking
                      FROM (
                          SELECT
                              package_name,
                              app_name,
                              is_system,
                              is_tracking,
                              range_overlap_flag,
                              COALESCE(removed_at, 'infinity'::timestamptz) AS sort_removed_at,
                              last_seen_at
                        FROM presence_rows
                          UNION ALL
                          SELECT
                              a.package_name,
                              a.app_name,
                              a.is_system,
                              a.is_tracking,
                              0 AS range_overlap_flag,
                              'infinity'::timestamptz AS sort_removed_at,
                            a.updated_at AS last_seen_at
                        FROM apps a
                        WHERE a.device_id = %s
                    ) ranked
                    ORDER BY package_name, range_overlap_flag DESC, sort_removed_at DESC, last_seen_at DESC
                ),
                days(day_tk) AS (
                    SELECT from_day_tk FROM range_bounds
                    UNION ALL
                    SELECT (day_tk + interval '1 day')::date
                    FROM days, range_bounds
                    WHERE day_tk < to_day_tk
                ),
                  sessions AS (
                      SELECT
                          u.package_name,
                          COALESCE(am.app_name, u.package_name) AS app_name,
                          COALESCE(am.is_system, FALSE) AS is_system,
                          LEAST(
                          u.foreground_ms,
                              GREATEST(EXTRACT(EPOCH FROM (u.end_time - u.start_time)) * 1000.0, 0)
                          ) AS foreground_ms,
                        u.start_time AS start_ts,
                        u.end_time AS end_ts
                    FROM usage_sessions u
                    LEFT JOIN app_meta am
                      ON am.package_name = u.package_name
                      WHERE u.device_id = %s
                        AND u.end_time > %s
                        AND u.start_time < %s
                        AND COALESCE(am.is_tracking, FALSE) = FALSE
                  ),
                  day_alloc AS (
                      SELECT
                          d.day_tk AS day,
                          s.package_name,
                          s.app_name,
                          s.is_system,
                          CASE
                              WHEN EXTRACT(EPOCH FROM (s.end_ts - s.start_ts)) <= 0 THEN 0.0
                              ELSE
                                  s.foreground_ms * (
                                    EXTRACT(EPOCH FROM (
                                        LEAST(
                                            s.end_ts,
                                            rb.to_ts,
                                            (d.day_tk::timestamptz + interval '1 day' - interval '5 hours')
                                        ) - GREATEST(
                                            s.start_ts,
                                            rb.from_ts,
                                            (d.day_tk::timestamptz - interval '5 hours')
                                        )
                                    )) / EXTRACT(EPOCH FROM (s.end_ts - s.start_ts))
                                )
                        END AS weighted_ms
                    FROM days d
                    CROSS JOIN range_bounds rb
                    CROSS JOIN sessions s
                    WHERE LEAST(
                        s.end_ts,
                        rb.to_ts,
                        (d.day_tk::timestamptz + interval '1 day' - interval '5 hours')
                    ) > GREATEST(
                        s.start_ts,
                        rb.from_ts,
                        (d.day_tk::timestamptz - interval '5 hours')
                    )
                  )
                  SELECT
                      d.day_tk AS day,
                      da.package_name,
                      da.app_name,
                      da.is_system,
                      COALESCE(ROUND(SUM(da.weighted_ms)), 0)::bigint AS total_foreground_ms
                  FROM days d
                  LEFT JOIN day_alloc da ON da.day = d.day_tk
                  GROUP BY d.day_tk, da.package_name, da.app_name, da.is_system
                  ORDER BY d.day_tk ASC, total_foreground_ms DESC, da.app_name ASC
                  """,
                  (
                      from_iso,
                      to_iso,
                    from_iso,
                    to_iso,
                    device_id.upper(),
                    device_id.upper(),
                      device_id.upper(),
                      from_iso,
                      to_iso,
                  ),
              ).fetchall()
            day_totals: dict[str, int] = {}
            ordered_days: list[str] = []
            for row in rows:
                day = row["day"]
                if not day:
                    continue
                day_key = day.isoformat() if hasattr(day, "isoformat") else str(day)
                if day_key not in day_totals:
                    day_totals[day_key] = 0
                    ordered_days.append(day_key)
                package_name = row.get("package_name", "") or ""
                app_name = row.get("app_name", "") or package_name
                is_system = _classify_is_system(package_name, app_name, row.get("is_system", False))
                if not include_system and is_system:
                    continue
                total_ms = int(row.get("total_foreground_ms") or 0)
                day_totals[day_key] = day_totals.get(day_key, 0) + total_ms
            days_payload = [
                {"day": day_key, "total_foreground_ms": day_totals.get(day_key, 0)}
                for day_key in ordered_days
            ]
            return self._write_json(
                200,
                {"device_id": device_id.upper(), "from": from_iso, "to": to_iso, "days": days_payload},
            )
        finally:
            conn.close()

    def _get_device_data_usage(self, device_id: str, query: dict[str, list[str]]) -> None:
        from_iso, to_iso = self._parse_and_validate_range(query)
        return self._write_json(
            200,
            {
                "device_id": device_id.upper(),
                "from": from_iso,
                "to": to_iso,
                "total_bytes": 0,
            },
        )

    def _get_device_data_usage_daily(self, device_id: str, query: dict[str, list[str]]) -> None:
        from_iso, to_iso = self._parse_and_validate_range(query)
        return self._write_json(
            200,
            {
                "device_id": device_id.upper(),
                "from": from_iso,
                "to": to_iso,
                "days": [],
            },
        )


def run() -> None:
    init_db()
    start_background_workers()
    server = UsageHTTPServer((HOST, PORT), ApiHandler)
    print(f"Usage backend listening on http://{HOST}:{PORT} DB=postgres")
    try:
        server.serve_forever()
    finally:
        server.server_close()
        stop_background_workers()


if __name__ == "__main__":
    run()
