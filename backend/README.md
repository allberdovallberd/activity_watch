# Backend

## Run

```powershell
cd backend
pip install -r requirements.txt
setx USAGE_DB_DSN "postgresql://usage_user:usage_pass@localhost:5432/usage_db"
python server.py
```

Ensure the database exists before starting the server.

## Admin auth env

- `USAGE_ADMIN_USERNAME` (default `admin`)
- `USAGE_ADMIN_PASSWORD` (default `admin123`)
- `USAGE_DB_DSN` or `DATABASE_URL` (PostgreSQL connection string)

## Key API

- `POST /api/v1/admin/login`
- `GET/POST/PUT/DELETE /api/v1/main-categories[...]`
- `GET/POST/PUT/DELETE /api/v1/sub-categories[...]`
- `GET /api/v1/devices`
- `POST /api/v1/devices` (create)
- `PUT /api/v1/devices/{device_id}` (edit ID/category)
- `DELETE /api/v1/devices/{device_id}` (delete/disable)
- `POST /api/v1/devices/register` (APK)
- `POST /api/v1/sync` (APK)

## Device binding behavior

- APK sends `device_id` + `client_instance_id`.
- One device ID can be active on one physical installation at a time.
- If admin deletes/reuses an ID, previously bound old installation is blocked.
