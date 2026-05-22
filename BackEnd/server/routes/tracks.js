/**
 * 轨迹回放路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const trackController = require('../controllers/trackController');

router.use(authMiddleware);

router.get('/heatmap', managerOrAdmin, trackController.getHeatmap);
// 自己的轨迹 — 任何登录用户可查看
router.get('/me', trackController.getMyTrack);
// 查看他人轨迹 — 需要管理员或经理权限
router.get('/:userId', managerOrAdmin, trackController.getTrack);

module.exports = router;
