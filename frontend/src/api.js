// src/api.js
// A single place that configures Axios (our HTTP client) and exposes API calls.
// Centralizing this means the base URL and headers are defined once.

import axios from 'axios';

// REACT_APP_API_URL is baked in AT BUILD TIME by Create React App. Any env var
// used in the browser MUST start with REACT_APP_. If it is empty we fall back to
// "/api", which works when Nginx proxies /api to the backend (see nginx.conf).
//
// Important gotcha: React is static files running in the user's browser, so it
// cannot read Kubernetes env vars at runtime — the value is frozen at build.
const baseURL = process.env.REACT_APP_API_URL || '/api';

const client = axios.create({
  baseURL,
  timeout: 5000,
});

// Fetch the greeting message from the backend.
export async function fetchMessage() {
  const res = await client.get('/message');
  return res.data; // { message: "..." }
}

// Fetch runtime info (which pod answered, version, uptime).
export async function fetchInfo() {
  const res = await client.get('/info');
  return res.data; // { hostname, version, uptimeSeconds }
}
