// controllers/healthController.js
// Controllers hold the actual logic that runs for a route. Splitting "routes"
// (the URL map) from "controllers" (the logic) keeps files small and testable.

// Liveness probe response. Returning 200 tells Kubernetes the process is alive.
exports.getHealth = (req, res) => {
  res.status(200).json({ status: 'ok', check: 'liveness' });
};

// Readiness probe response. Here we always return ready because the API has no
// external dependency yet. When you add MongoDB, check the DB connection here
// and return 503 until it is connected.
exports.getReady = (req, res) => {
  res.status(200).json({ status: 'ready', check: 'readiness' });
};
