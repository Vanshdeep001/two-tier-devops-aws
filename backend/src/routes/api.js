// routes/api.js
// The business/application routes. These are mounted under "/api" in app.js,
// so a route defined here as "/message" is reachable at "/api/message".

const express = require('express');
const router = express.Router();
const messageController = require('../controllers/messageController');

// GET /api/message -> returns a JSON greeting the frontend displays.
router.get('/message', messageController.getMessage);

// GET /api/info -> returns runtime info so you can prove which pod/version
// answered (useful when demonstrating rolling updates and load balancing).
router.get('/info', messageController.getInfo);

module.exports = router;
