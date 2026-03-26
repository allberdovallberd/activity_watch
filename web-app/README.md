# Web App

See the repository root `README.md` for the full installation and deployment guide.

Quick notes:

- simple local hosting:

```bash
cd web-app
python3 -m http.server 5173 --bind 0.0.0.0
```

- production hosting on Linux is better with nginx
- backend URL default is defined in `web-app/common.js`
- the browser can also store an overridden backend URL in local storage
