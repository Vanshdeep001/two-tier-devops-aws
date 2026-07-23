# Frontend — React (served by Nginx in production)

This folder is the **presentation tier**. In development it runs via the CRA dev
server (`npm start`). In production it is compiled to static files and served by
**Nginx**, which also **reverse-proxies `/api/*` to the backend** so the browser
only ever talks to one origin.

---

## File-by-file: what each file does

| File | Role |
|------|------|
| `package.json` | Dependencies (`react`, `react-dom`, `axios`) and scripts (`start`, `build`, `test`). |
| `public/index.html` | The single HTML page React mounts into (`<div id="root">`). |
| `src/index.js` | JS entry point — renders `<App />` into the root div. |
| `src/App.js` | Main component. Calls the backend on load and displays the result. |
| `src/api.js` | Axios setup + the API call functions. One place for the base URL. |
| `src/App.css` / `src/index.css` | Component and global styles. |
| `src/App.test.js` | A render test (mocks the API) so CI has a frontend test to run. |
| `src/setupTests.js` | Adds `toBeInTheDocument()` and friends for tests. |
| `nginx.conf` | Production web server config: serve static files + proxy `/api`. |
| `Dockerfile` | Multi-stage: build React, then serve with Nginx. |
| `.dockerignore` | Keeps `node_modules`, `build`, `.env` out of the image. |
| `.env.example` | Template for the build-time `REACT_APP_API_URL`. |

---

## The one thing people get wrong: React env vars are build-time

React compiles to static files that run in the **user's browser**. The browser
cannot read Kubernetes/Docker runtime env vars. So `REACT_APP_API_URL` is frozen
into the JS bundle **when you run `npm run build`** (that's why the Dockerfile
passes it as a build `ARG`).

To avoid this problem entirely, the production build uses a **relative `/api`**
path and lets **Nginx proxy** it to the backend. That way the same image works
in any cluster without rebuilding, and there is **no CORS** because the browser
sees a single origin.

```
Browser ──> Nginx (this container) ──/api──> backend-service:5000
            static React files served here
```

---

## Run locally (dev server)

```bash
cd frontend
npm install
cp .env.example .env
npm start          # opens http://localhost:3000
```

(Backend must be running on port 5000 for data to load.)

## Build & run the container

```bash
# Build (optionally override the API URL baked in):
docker build -t two-tier-frontend:local .

# Run, pointing the proxy at a reachable backend:
docker run -p 8080:80 -e BACKEND_URL=http://host.docker.internal:5000 two-tier-frontend:local
# open http://localhost:8080
```

---

## Common mistakes
- **Expecting to change the API URL at runtime** → it's baked in at build. Use
  the Nginx `/api` proxy instead (this repo does).
- **Forgetting `try_files ... /index.html`** → refreshing a client-side route
  returns 404. Our `nginx.conf` handles it.
- **`envsubst` eating `$uri`/`$host`** → we set `NGINX_ENVSUBST_FILTER=BACKEND_URL`
  so only `${BACKEND_URL}` is substituted.

## Interview questions this folder can answer
- *Why serve React with Nginx instead of Node in production?* Static files don't
  need a JS runtime; Nginx is faster, smaller, and battle-tested for static +
  reverse proxy.
- *Why are React env vars build-time, and how do you handle per-env config?*
  Bake at build, or (better) use a relative path + reverse proxy, or fetch a
  `/config.json` at runtime.
- *What is a reverse proxy and why use one here?* Nginx forwards `/api` to the
  backend, hiding it from the internet and removing CORS.
