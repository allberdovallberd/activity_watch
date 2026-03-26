# Backend

See the repository root `README.md` for the full installation and deployment guide.

Quick notes:

- backend uses PostgreSQL
- runtime configuration comes from environment variables or `backend/.env`
- initial admin bootstrap is environment-driven:
  - `USAGE_ADMIN_USERNAME`
  - `USAGE_ADMIN_PASSWORD`
- after bootstrap, admin login is validated against the database

Sample config:

```bash
USAGE_DB_DSN=postgresql://usage_user:usage_pass@localhost:5432/usage_db
USAGE_SERVER_HOST=0.0.0.0
USAGE_SERVER_PORT=8080
USAGE_ADMIN_USERNAME=admin
USAGE_ADMIN_PASSWORD=change-me
```

Run manually:

```bash
cd backend
source .venv/bin/activate
python server.py
```
