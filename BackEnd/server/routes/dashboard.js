/**
 * 数据看板路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const dashboardController = require('../controllers/dashboardController');

router.use(authMiddleware);

router.get('/stats', managerOrAdmin, dashboardController.getStats);
router.get('/trend', managerOrAdmin, dashboardController.getTrend);
router.get('/distribution', managerOrAdmin, dashboardController.getDistribution);
router.get('/anomalies', managerOrAdmin, dashboardController.getAnomalies);
router.get('/todos', managerOrAdmin, dashboardController.getTodos);

module.exports = router;
