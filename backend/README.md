# Backend — Node.js + Express REST API

This folder is the **API tier** of the two-tier app. It is a small, stateless
Express server that returns JSON. It has **no database** today, but it is
structured (routes → controllers) so you can add MongoDB later by editing one
controller.

---

## File-by-file: what each file does

| File | Role |
|------|------|
| `package.json` | Declares dependencies (`express`, `cors`), the test tools (`jest`, `supertest`), and the `start`/`test` scripts. This is what `npm install` reads. |
| `src/server.js` | **Entry point.** Starts the HTTP server on `PORT` and handles graceful shutdown (SIGTERM). |
| `src/app.js` | Builds the Express app: JSON parsing, CORS, and mounts the routers. Kept separate from `server.js` so tests can use the app without opening a port. |
| `src/routes/health.js` | URL map for `/health` (liveness) and `/ready` (readiness) probes. |
| `src/routes/api.js` | URL map for the business endpoints `/api/message` and `/api/info`. |
| `src/controllers/healthController.js` | Logic for the health/readiness probes. |
| `src/controllers/messageController.js` | Logic for the business endpoints. **This is where DB code would go.** |
| `tests/health.test.js` | Jest + Supertest tests. CI runs these before building the image. |
| `Dockerfile` | Multi-stage build that produces a small, non-root production image. |
| `.dockerignore` | Keeps `node_modules`, `.env`, `.git`, tests out of the image. |
| `.env.example` | Template of supported environment variables. Copy to `.env` locally. |

### Why "routes" and "controllers" are separate
- **Routes** answer *"what URL maps to what?"*
- **Controllers** answer *"what happens when that URL is hit?"*

Enterprise codebases split them so files stay small, logic is unit-testable, and
multiple routes can reuse the same controller function.

---

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness probe — is the process alive? |
| GET | `/ready` | Readiness probe — ready to serve traffic? |
| GET | `/api/message` | Returns `{ "message": "..." }` for the frontend. |
| GET | `/api/info` | Returns hostname (pod name), version, uptime. |

---

## Run locally

```bash
cd backend
npm install
cp .env.example .env
npm start
# In another terminal:
curl http://localhost:5000/health
curl http://localhost:5000/api/message
```

## Run tests

```bash
npm test
```

## Build & run the container

```bash
docker build -t two-tier-backend:local .
docker run -p 5000:5000 --env-file .env two-tier-backend:local
```

---

## Common mistakes
- **Binding to `127.0.0.1` inside a container** → nothing outside can reach it.
  Always bind `0.0.0.0` (we do, in `server.js`).
- **Forgetting CORS** → the browser silently blocks frontend calls. Symptom:
  request works in `curl` but fails in the browser console.
- **Baking `.env` into the image** → secrets leak. `.dockerignore` prevents it.
- **Running as root in the container** → security risk. We use `USER node`.

## Interview questions this folder can answer
- *What is the difference between liveness and readiness probes?*
  Liveness failure → pod is **restarted**. Readiness failure → pod is **removed
  from the Service endpoints** (no traffic) but not restarted.
- *Why separate `app.js` from `server.js`?* So tests import the app without
  starting a real server, and so the same app can run under different servers.
- *Why multi-stage Docker builds?* To keep build-time dependencies out of the
  final image → smaller, faster, more secure.
- *What does CORS actually do?* It's a browser security mechanism; the server
  sends headers telling the browser which origins may read the response.
