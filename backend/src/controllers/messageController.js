// controllers/messageController.js
// Business logic for the /api routes. Today it returns static JSON; later this
// is exactly where you would query MongoDB and return real data instead.

const os = require('os');

exports.getMessage = (req, res) => {
  // MESSAGE is configurable via environment (ConfigMap in Kubernetes), so you
  // can change the greeting without rebuilding the image.
  const message = process.env.MESSAGE || 'Hello from the Node.js + Express backend!';
  res.status(200).json({ message });
};

exports.getInfo = (req, res) => {
  res.status(200).json({
    // os.hostname() is the pod name inside Kubernetes. Refresh the page and
    // watch it change across replicas — proof the Service is load balancing.
    hostname: os.hostname(),
    // APP_VERSION is injected at deploy time (we set it to the Git SHA) so you
    // can confirm which build is actually running.
    version: process.env.APP_VERSION || 'dev',
    uptimeSeconds: Math.round(process.uptime()),
  });
};
