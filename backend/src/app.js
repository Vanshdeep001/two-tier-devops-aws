// app.js
// This file builds the Express "app" object (the request handler) but does NOT
// start listening on a port. Keeping app creation separate from server startup
// lets our tests import the app and fire fake requests at it without opening a
// real network socket.

const express = require('express');
const cors = require('cors');

const healthRoutes = require('./routes/health');
const apiRoutes = require('./routes/api');

const app = express();

// Parse incoming JSON bodies into req.body automatically.
app.use(express.json());

// CORS = Cross-Origin Resource Sharing.
// The React frontend runs on a different origin (different host/port) than this
// API, so the browser blocks calls by default. This middleware adds the headers
// that tell the browser "these origins are allowed to call me".
// CORS_ORIGIN is read from the environment so we can lock it down in production.
const allowedOrigin = process.env.CORS_ORIGIN || '*';
app.use(cors({ origin: allowedOrigin }));

// Mount routers. Everything in healthRoutes is served under "/", and everything
// in apiRoutes is served under "/api".
app.use('/', healthRoutes);
app.use('/api', apiRoutes);

// Fallback 404 handler for any route we did not define.
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', path: req.originalUrl });
});

module.exports = app;
