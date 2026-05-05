/**
 * 离线打卡路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const offlineCheckinController = require('../controllers/offlineCheckinController');

router.use(authMiddleware);

router.post('/', offlineCheckinController.submitOfflineCheckin);
router.get('/mine', offlineCheckinController.getMyOfflineCheckins);
router.post('/sync', offlineCheckinController.syncOfflineCheckins);
router.get('/', managerOrAdmin, offlineCheckinController.getAllOfflineCheckins);

module.exports = router;
