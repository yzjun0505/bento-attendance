/**
 * 项目进度路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const progressController = require('../controllers/progressController');

router.use(authMiddleware);

router.get('/progress/workbench', progressController.getWorkbench);
router.get('/projects/:projectId/progress-summary', progressController.getProjectSummary);

module.exports = router;