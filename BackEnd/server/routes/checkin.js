/**
 * 打卡路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const checkinController = require('../controllers/checkinController');

router.use(authMiddleware);

router.post('/', checkinController.submitCheckin);
router.get('/reserve-code', checkinController.reserveCode);
router.get('/search-code', managerOrAdmin, checkinController.searchByWatermarkCode);
router.get('/today-stats', managerOrAdmin, checkinController.getTodayStats);
router.get('/export', managerOrAdmin, checkinController.exportCheckins);
router.get('/', checkinController.getCheckins);

module.exports = router;
