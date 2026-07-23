// routes/health.js
// Defines the health-check endpoints. Kubernetes calls these to decide whether
// the pod is alive (liveness) and ready to receive traffic (readiness).

const express = require('express');
const router = express.Router();
const healthController = require('../controllers/healthController');

// Liveness: "is the process running?" If this fails, K8s restarts the pod.
router.get('/health', healthController.getHealth);

// Readiness: "is the app ready to serve traffic?" If this fails, K8s stops
// sending traffic but does NOT restart the pod. For a stateless API the answer
// is usually the same as liveness, but we keep a separate route so you can add
// checks later (e.g. "is the database connected?").
router.get('/ready', healthController.getReady);

module.exports = router;
