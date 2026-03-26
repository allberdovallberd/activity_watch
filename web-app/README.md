# Web App

## Run

```bash
cd web-app
python -m http.server 5173
```

Open: `http://localhost:5173`

## Features

- Admin login
- Multi-page UI:
  - Dashboard: `index.html`
  - Categories: `categories.html`
  - Devices: `devices.html`
- Dashboard:
  - device list with search + Faculty + Year filters
  - pagination (50 per page)
- Categories page:
  - Main category (Faculty) CRUD
  - Sub category (Year intake) CRUD
- Devices page:
  - device create/edit/delete
  - search + Faculty + Year filters
  - pagination (50 per page)
