# Activity Watch

This repository contains:

- `backend/` — Python API server with PostgreSQL storage
- `web-app/` — browser dashboard and admin pages
- `android-app/` — Android collector app (not pushed to GitHub in the current repo setup)

This README covers installing and running the `backend/` and `web-app/` on another machine.

## What You Need

For the backend:

- Python 3.10+
- PostgreSQL
- Git

For the web app:

- Python 3
- or nginx for production static hosting

## Repository Setup

Clone the repository:

```bash
git clone https://github.com/allberdovallberd/activity_watch.git
cd activity_watch
```

## Backend Setup

### 1. Create PostgreSQL database and user

Using `psql`:

```sql
CREATE USER usage_user WITH PASSWORD 'usage_pass';
CREATE DATABASE usage_db OWNER usage_user;
GRANT ALL PRIVILEGES ON DATABASE usage_db TO usage_user;
\c usage_db
GRANT ALL ON SCHEMA public TO usage_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO usage_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO usage_user;
```

### 2. Configure environment

Copy the sample file:

```bash
cp backend/.env.example backend/.env
```

Edit `backend/.env` and set real values.

Important variables:

- `USAGE_DB_DSN`
- `USAGE_SERVER_HOST`
- `USAGE_SERVER_PORT`
- `USAGE_ADMIN_USERNAME`
- `USAGE_ADMIN_PASSWORD`

Notes:

- `USAGE_ADMIN_USERNAME` and `USAGE_ADMIN_PASSWORD` are used only for first-start bootstrap if no admin credentials exist in the database yet.
- After bootstrap, admin login is validated against the database, not against hardcoded code values.
- If you set one of `USAGE_ADMIN_USERNAME` / `USAGE_ADMIN_PASSWORD`, you must set both.
- `USAGE_DEFAULT_WEB_USERNAME` and `USAGE_DEFAULT_WEB_PASSWORD` are optional first-start bootstrap values for a normal web user.

### 3. Install Python dependencies

#### Windows

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt
```

#### Linux

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

If the Linux server has no PyPI access but has `python3-psycopg2` installed from apt, recreate the venv with system packages visible:

```bash
rm -rf .venv
python3 -m venv .venv --system-site-packages
source .venv/bin/activate
```

### 4. Run backend manually

#### Windows

```powershell
cd backend
.venv\Scripts\Activate.ps1
$env:USAGE_DB_DSN="postgresql://usage_user:usage_pass@localhost:5432/usage_db"
$env:USAGE_SERVER_HOST="0.0.0.0"
$env:USAGE_SERVER_PORT="8080"
$env:USAGE_ADMIN_USERNAME="admin"
$env:USAGE_ADMIN_PASSWORD="change-me"
python server.py
```

#### Linux

```bash
cd backend
source .venv/bin/activate
export USAGE_DB_DSN="postgresql://usage_user:usage_pass@localhost:5432/usage_db"
export USAGE_SERVER_HOST="0.0.0.0"
export USAGE_SERVER_PORT="8080"
export USAGE_ADMIN_USERNAME="admin"
export USAGE_ADMIN_PASSWORD="change-me"
python server.py
```

Expected behavior:

- backend listens on `http://SERVER_IP:8080`
- tables are created automatically
- retention cleanup worker starts automatically

### 5. Production backend with systemd (Linux)

Example service file:

```ini
[Unit]
Description=Activity Watch Backend
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=/home/YOUR_USER/activity_watch/backend
EnvironmentFile=/etc/activity-watch/backend.env
ExecStart=/home/YOUR_USER/activity_watch/backend/.venv/bin/python /home/YOUR_USER/activity_watch/backend/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Example environment file `/etc/activity-watch/backend.env`:

```bash
USAGE_DB_DSN=postgresql://usage_user:usage_pass@localhost:5432/usage_db
USAGE_SERVER_HOST=0.0.0.0
USAGE_SERVER_PORT=8080
USAGE_ADMIN_USERNAME=admin
USAGE_ADMIN_PASSWORD=change-me
USAGE_DEFAULT_WEB_USERNAME=
USAGE_DEFAULT_WEB_PASSWORD=
USAGE_ADMIN_TOKEN_HOURS=12
USAGE_DB_POOL_MIN_SIZE=4
USAGE_DB_POOL_MAX_SIZE=24
USAGE_RETENTION_CLEANUP_SECONDS=3600
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable activity-backend
sudo systemctl start activity-backend
sudo systemctl status activity-backend --no-pager -l
```

## Web App Setup

### Development / simple static hosting

#### Windows

```powershell
cd web-app
python -m http.server 5173
```

#### Linux

```bash
cd web-app
python3 -m http.server 5173 --bind 0.0.0.0
```

Open:

- `http://localhost:5173` on the same machine
- `http://SERVER_IP:5173` from another machine

### Production static hosting with nginx (Linux)

Copy files:

```bash
sudo mkdir -p /var/www/activity_watch
sudo cp -r ~/activity_watch/web-app/* /var/www/activity_watch/
```

Example nginx site:

```nginx
server {
    listen 80;
    server_name SERVER_IP_OR_NAME;

    root /var/www/activity_watch;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Enable and restart:

```bash
sudo ln -s /etc/nginx/sites-available/activity_watch /etc/nginx/sites-enabled/activity_watch
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```

Then the web app is available at:

- `http://SERVER_IP`

## Backend URL in the Web App

The web app stores its backend URL in browser local storage.

Default source in code:

- `web-app/common.js`

If needed, edit:

```js
const BACKEND_BASE_URL = "http://SERVER_IP:8080";
```

If you use nginx for the web app and serve backend on the same host, set it to your real backend URL.

## Admin Login Bootstrap

Admin credentials are no longer meant to be hardcoded as the long-term runtime source.

Recommended first start:

1. set `USAGE_ADMIN_USERNAME`
2. set `USAGE_ADMIN_PASSWORD`
3. start backend once
4. login to `/admin/`
5. manage users from the admin UI after that

The admin login is stored in the database after bootstrap.

## Firewall / Network

Open the ports you actually use:

- backend: `8080` or `8081`
- web app: `5173` if using Python server
- web app: `80` if using nginx

Examples:

### Windows Firewall

```powershell
netsh advfirewall firewall add rule name="Usage Backend 8080" dir=in action=allow protocol=TCP localport=8080
netsh advfirewall firewall add rule name="Usage Web 5173" dir=in action=allow protocol=TCP localport=5173
```

### Linux ufw

```bash
sudo ufw allow 8080/tcp
sudo ufw allow 5173/tcp
sudo ufw allow 80/tcp
sudo ufw status
```

## Verification

Backend:

```bash
curl http://127.0.0.1:8080
```

A response like `{"error":"Not found"}` at `/` is acceptable.

Web app:

```bash
curl http://127.0.0.1:5173
```

or, with nginx:

```bash
curl http://127.0.0.1
```

## Updating on the Server

Pull updates:

```bash
cd ~/activity_watch
git pull
```

Backend:

```bash
cd ~/activity_watch/backend
source .venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart activity-backend
```

Web app with nginx:

```bash
sudo cp -r ~/activity_watch/web-app/* /var/www/activity_watch/
sudo systemctl restart nginx
```
