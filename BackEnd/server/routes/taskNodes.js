/**
 * 任务节点与进度上报路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const taskNodeController = require('../controllers/taskNodeController');

router.use(authMiddleware);

router.get('/projects/:projectId/nodes', taskNodeController.getNodesByProject);
router.post('/projects/:projectId/nodes', taskNodeController.createNode);
router.put('/nodes/:id', taskNodeController.updateNode);
router.delete('/nodes/:id', taskNodeController.deleteNode);
router.get('/nodes/:id/reports', taskNodeController.getReportsByNode);
router.post('/nodes/:id/reports', taskNodeController.createReport);
router.post('/nodes/:id/review', taskNodeController.reviewNode);

module.exports = router;
