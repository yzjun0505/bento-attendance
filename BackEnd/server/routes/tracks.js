/**
 * 轨迹回放路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const trackController = require('../controllers/trackController');

router.use(authMiddleware);

router.get('/heatmap', managerOrAdmin, trackController.getHeatmap);
router.get('/:userId', managerOrAdmin, trackController.getTrack);

module.exports = router;
