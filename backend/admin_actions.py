import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Callable

import psycopg


WriteJson = Callable[[int, dict[str, Any]], None]
DbConnect = Callable[[], psycopg.Connection]
UtcNowIso = Callable[[], str]


def hash_password(password: str, salt: str) -> str:
    return hashlib.sha256((salt + password).encode("utf-8")).hexdigest()


def ensure_admin_credentials(
    conn: psycopg.Connection,
    *,
    username: str,
    password: str,
    utc_now_iso: UtcNowIso,
) -> None:
    row = conn.execute("SELECT id FROM admin_credentials LIMIT 1").fetchone()
    if row:
        return
    salt = secrets.token_hex(16)
    password_hash = hash_password(password, salt)
    conn.execute(
        """
        INSERT INTO admin_credentials(username, password_hash, salt, updated_at)
        VALUES (%s, %s, %s, %s)
        """,
        (username, password_hash, salt, utc_now_iso()),
    )


def ensure_default_web_user(
    conn: psycopg.Connection,
    *,
    username: str,
    password: str,
    utc_now_iso: UtcNowIso,
) -> None:
    row = conn.execute("SELECT username FROM web_users LIMIT 1").fetchone()
    if row:
        return
    salt = secrets.token_hex(16)
    password_hash = hash_password(password, salt)
    conn.execute(
        """
        INSERT INTO web_users(username, password_hash, salt, updated_at)
        VALUES (%s, %s, %s, %s)
        """,
        (username, password_hash, salt, utc_now_iso()),
    )


def ensure_admin_settings(conn: psycopg.Connection, *, utc_now_iso: UtcNowIso) -> None:
    row = conn.execute("SELECT id FROM admin_settings WHERE id = 1").fetchone()
    if row:
        return
    conn.execute(
        """
        INSERT INTO admin_settings(id, allow_bootstrap, updated_at)
        VALUES (1, TRUE, %s)
        """,
        (utc_now_iso(),),
    )


def bootstrap_allowed(conn: psycopg.Connection) -> bool:
    row = conn.execute("SELECT allow_bootstrap FROM admin_settings WHERE id = 1").fetchone()
    if not row:
        return True
    return bool(row["allow_bootstrap"])


def disable_bootstrap(conn: psycopg.Connection, *, utc_now_iso: UtcNowIso) -> None:
    conn.execute(
        "UPDATE admin_settings SET allow_bootstrap = FALSE, updated_at = %s WHERE id = 1",
        (utc_now_iso(),),
    )


def get_admin_credentials(conn: psycopg.Connection) -> dict[str, Any] | None:
    return conn.execute(
        "SELECT username, password_hash, salt FROM admin_credentials LIMIT 1"
    ).fetchone()


def set_admin_credentials(
    conn: psycopg.Connection,
    username: str,
    password: str,
    *,
    utc_now_iso: UtcNowIso,
) -> None:
    salt = secrets.token_hex(16)
    password_hash = hash_password(password, salt)
    now = utc_now_iso()
    existing = conn.execute("SELECT id FROM admin_credentials LIMIT 1").fetchone()
    if existing:
        conn.execute(
            """
            UPDATE admin_credentials
            SET username = %s, password_hash = %s, salt = %s, updated_at = %s
            WHERE id = %s
            """,
            (username, password_hash, salt, now, existing["id"]),
        )
    else:
        conn.execute(
            """
            INSERT INTO admin_credentials(username, password_hash, salt, updated_at)
            VALUES (%s, %s, %s, %s)
            """,
            (username, password_hash, salt, now),
        )


def get_web_user(conn: psycopg.Connection, username: str) -> dict[str, Any] | None:
    return conn.execute(
        "SELECT username, password_hash, salt, updated_at FROM web_users WHERE username = %s",
        (username,),
    ).fetchone()


def set_web_user_password(
    conn: psycopg.Connection,
    username: str,
    password: str,
    *,
    utc_now_iso: UtcNowIso,
) -> None:
    salt = secrets.token_hex(16)
    password_hash = hash_password(password, salt)
    now = utc_now_iso()
    conn.execute(
        """
        INSERT INTO web_users(username, password_hash, salt, updated_at)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (username) DO UPDATE SET
            password_hash = EXCLUDED.password_hash,
            salt = EXCLUDED.salt,
            updated_at = EXCLUDED.updated_at
        """,
        (username, password_hash, salt, now),
    )


def get_authorized_token_type(headers: Any, *, db_connect: DbConnect, utc_now_iso: UtcNowIso) -> str | None:
    auth = headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[len("Bearer ") :].strip()
    conn = db_connect()
    try:
        row = conn.execute(
            "SELECT token_type FROM admin_tokens WHERE token = %s AND expires_at > %s",
            (token, utc_now_iso()),
        ).fetchone()
        return row["token_type"] if row else None
    finally:
        conn.close()


def handle_admin_login(
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    admin_username: str,
    admin_password: str,
    admin_token_hours: int,
    utc_now_iso: UtcNowIso,
) -> None:
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    if username != admin_username or password != admin_password:
        return write_json(401, {"error": "Invalid credentials"})
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=admin_token_hours)
    conn = db_connect()
    try:
        conn.execute(
            """
            INSERT INTO admin_tokens(token, token_type, expires_at, created_at)
            VALUES (%s, 'admin', %s, %s)
            ON CONFLICT (token) DO UPDATE
            SET token_type = EXCLUDED.token_type,
                expires_at = EXCLUDED.expires_at
            """,
            (token, expires_at.isoformat(), utc_now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    return write_json(200, {"ok": True, "token": token, "expires_at": expires_at.isoformat()})


def handle_user_login(
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    admin_token_hours: int,
    utc_now_iso: UtcNowIso,
) -> None:
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    conn = db_connect()
    try:
        user = get_web_user(conn, username)
    finally:
        conn.close()
    if not user:
        return write_json(401, {"error": "Invalid credentials"})
    expected_hash = hash_password(password, user["salt"])
    if expected_hash != user["password_hash"]:
        return write_json(401, {"error": "Invalid credentials"})
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=admin_token_hours)
    conn = db_connect()
    try:
        conn.execute(
            """
            INSERT INTO admin_tokens(token, token_type, expires_at, created_at)
            VALUES (%s, 'user', %s, %s)
            ON CONFLICT (token) DO UPDATE
            SET token_type = EXCLUDED.token_type,
                expires_at = EXCLUDED.expires_at
            """,
            (token, expires_at.isoformat(), utc_now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    return write_json(
        200,
        {"ok": True, "token": token, "expires_at": expires_at.isoformat(), "username": username},
    )


def handle_admin_set_credentials(
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    utc_now_iso: UtcNowIso,
    is_admin_authorized: Callable[[], bool],
) -> None:
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    if not username or not password:
        raise ValueError("Missing required fields: username, password")
    conn = db_connect()
    try:
        existing = conn.execute("SELECT id FROM admin_credentials LIMIT 1").fetchone()
        if existing and not is_admin_authorized():
            if not bootstrap_allowed(conn):
                return write_json(401, {"error": "Unauthorized"})
        set_admin_credentials(conn, username, password, utc_now_iso=utc_now_iso)
        conn.execute("DELETE FROM admin_tokens")
        disable_bootstrap(conn, utc_now_iso=utc_now_iso)
        conn.commit()
        return write_json(200, {"ok": True})
    finally:
        conn.close()


def handle_get_web_users(*, write_json: WriteJson, db_connect: DbConnect) -> None:
    conn = db_connect()
    try:
        rows = conn.execute(
            "SELECT username, updated_at FROM web_users ORDER BY username ASC"
        ).fetchall()
        return write_json(200, {"users": [dict(r) for r in rows]})
    finally:
        conn.close()


def handle_create_web_user(
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    utc_now_iso: UtcNowIso,
) -> None:
    username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    if not username or not password:
        raise ValueError("Missing required fields: username, password")
    conn = db_connect()
    try:
        if get_web_user(conn, username):
            raise ValueError("User already exists")
        set_web_user_password(conn, username, password, utc_now_iso=utc_now_iso)
        conn.commit()
        return write_json(200, {"ok": True, "username": username})
    finally:
        conn.close()


def handle_update_web_user_password(
    username: str,
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    utc_now_iso: UtcNowIso,
) -> None:
    username = str(username or "").strip()
    password = str(data.get("password", "")).strip()
    if not username or not password:
        raise ValueError("Missing required fields: username, password")
    conn = db_connect()
    try:
        if not get_web_user(conn, username):
            raise ValueError("User not found")
        set_web_user_password(conn, username, password, utc_now_iso=utc_now_iso)
        conn.commit()
        return write_json(200, {"ok": True, "username": username})
    finally:
        conn.close()


def handle_update_web_user(
    username: str,
    data: dict[str, Any],
    *,
    write_json: WriteJson,
    db_connect: DbConnect,
    utc_now_iso: UtcNowIso,
) -> None:
    current_username = str(username or "").strip()
    next_username = str(data.get("username", "")).strip()
    password = str(data.get("password", "")).strip()
    if not current_username or not next_username or not password:
        raise ValueError("Missing required fields: username, password")
    conn = db_connect()
    try:
        existing = get_web_user(conn, current_username)
        if not existing:
            raise ValueError("User not found")
        if next_username != current_username and get_web_user(conn, next_username):
            raise ValueError("User already exists")
        salt = secrets.token_hex(16)
        password_hash = hash_password(password, salt)
        conn.execute(
            """
            UPDATE web_users
            SET username = %s, password_hash = %s, salt = %s, updated_at = %s
            WHERE username = %s
            """,
            (next_username, password_hash, salt, utc_now_iso(), current_username),
        )
        conn.commit()
        return write_json(200, {"ok": True, "username": next_username})
    finally:
        conn.close()
