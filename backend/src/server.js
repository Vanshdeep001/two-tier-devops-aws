// server.js
// The entry point that actually starts the HTTP server. It imports the app
// (the request handler) and binds it to a TCP port so it can accept traffic.

const app = require('./app');

// PORT comes from the environment (Kubernetes/Docker inject it). We default to
// 5000 for local development so `npm start` just works.
const PORT = process.env.PORT || 5000;

// 0.0.0.0 means "listen on all network interfaces". Inside a container you MUST
// bind to 0.0.0.0 (not 127.0.0.1), otherwise traffic from outside the container
// can never reach the process.
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend API listening on port ${PORT}`);
});

// Graceful shutdown: when Kubernetes stops a pod it sends SIGTERM. We close the
// server so in-flight requests finish instead of being killed abruptly.
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => process.exit(0));
});

module.exports = server;
