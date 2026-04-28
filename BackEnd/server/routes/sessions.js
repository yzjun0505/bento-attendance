const express = require('express');
const router = express.Router();
const { refreshToken, destroySession } = require('../controllers/sessionController');

router.post('/refresh', refreshToken);
router.post('/logout', destroySession);

module.exports = router;
