/**
 * 甲方项目授权路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const projectClientController = require('../controllers/projectClientController');

router.use(authMiddleware);

router.get('/', adminOnly, projectClientController.getClientProjects);
router.post('/', adminOnly, projectClientController.bindClientToProject);
router.delete('/:id', adminOnly, projectClientController.unbindClientFromProject);

module.exports = router;
