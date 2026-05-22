/**
 * 项目授权路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly, managerOrAdmin } = require('../middleware/auth');
const projectManagerController = require('../controllers/projectManagerController');

router.use(authMiddleware);

router.get('/', managerOrAdmin, projectManagerController.getManagerProjects);
router.post('/', adminOnly, projectManagerController.bindManagerToProject);
router.delete('/:id', adminOnly, projectManagerController.unbindManagerFromProject);

module.exports = router;
