# backend/Dockerfile
# A multi-stage build. Stage 1 installs dependencies; the final stage copies
# only what is needed to run. This keeps the final image small and avoids
# shipping build tools/dev dependencies to production.

# ---------- Stage 1: dependencies ----------
# "AS deps" names this stage so we can copy from it later.
# node:18-alpine = tiny Linux (Alpine) with Node 18. Small = faster pulls,
# smaller attack surface.
FROM node:18-alpine AS deps

# All following commands run inside /app inside the image.
WORKDIR /app

# Copy ONLY the manifest files first. Docker caches each layer; as long as these
# files don't change, Docker reuses the cached "npm install" layer on rebuilds.
COPY package*.json ./

# npm ci = clean, reproducible install from package-lock.json.
# --omit=dev skips devDependencies (jest/supertest) since we don't test here.
RUN npm ci --omit=dev

# ---------- Stage 2: runtime ----------
FROM node:18-alpine AS runtime

# NODE_ENV=production makes Express and libraries run in their optimized mode.
ENV NODE_ENV=production

WORKDIR /app

# Copy the already-installed node_modules from the deps stage.
COPY --from=deps /app/node_modules ./node_modules

# Copy the application source code.
COPY . .

# Run as the built-in non-root "node" user. Never run containers as root in
# production — if the app is compromised, root inside the container is worse.
USER node

# Documents that the app listens on 5000. This is informational; it does not
# actually publish the port (Kubernetes/`docker run -p` does that).
EXPOSE 5000

# The command that starts the container. "node src/server.js" (not npm) so
# signals like SIGTERM reach Node directly for graceful shutdown.
CMD ["node", "src/server.js"]
