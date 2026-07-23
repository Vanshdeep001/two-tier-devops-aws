# frontend/Dockerfile
# Multi-stage build:
#   Stage 1 ("build") compiles the React app into static files.
#   Stage 2 ("runtime") serves those files with Nginx.
# The final image contains ONLY Nginx + static files — no Node, no source code.

# ---------- Stage 1: build the React app ----------
FROM node:18-alpine AS build

WORKDIR /app

# Copy manifests first so Docker caches the npm install layer.
COPY package*.json ./
# npm install (not npm ci) to tolerate minor lockfile-resolution differences.
RUN npm install --no-audit --no-fund

# Copy the rest of the source and build the production bundle.
COPY . .

# REACT_APP_API_URL is a BUILD ARG because React env vars are frozen at build
# time. We default to "/api" so Nginx can proxy same-origin (no CORS needed).
ARG REACT_APP_API_URL=/api
ENV REACT_APP_API_URL=$REACT_APP_API_URL

# Produces the optimized static site in /app/build.
RUN npm run build

# ---------- Stage 2: serve with Nginx ----------
FROM nginx:1.27-alpine AS runtime

# Copy the compiled static files into Nginx's web root.
COPY --from=build /app/build /usr/share/nginx/html

# Place our config as a TEMPLATE. The official Nginx image runs `envsubst` on
# files in /etc/nginx/templates at startup, substituting ${BACKEND_URL}.
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Restrict envsubst to ONLY replace ${BACKEND_URL}. Without this filter, Nginx
# variables like $uri and $host would also be wiped out. Provide a sane default.
ENV NGINX_ENVSUBST_FILTER=BACKEND_URL
ENV BACKEND_URL=http://backend-service:5000

EXPOSE 80

# The base Nginx image already has the correct CMD to start Nginx in the
# foreground and run the envsubst template step first, so we don't override it.
