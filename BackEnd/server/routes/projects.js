/**
 * 项目管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const projectController = require('../controllers/projectController');

router.use(authMiddleware);

router.get('/all', projectController.getAllProjects);
router.get('/nearby', projectController.getNearbyProjects);
router.get('/', managerOrAdmin, projectController.getProjects);
router.get('/:id', managerOrAdmin, projectController.getProjectById);
router.post('/', managerOrAdmin, projectController.createProject);
router.put('/:id', managerOrAdmin, projectController.updateProject);
router.delete('/:id', managerOrAdmin, projectController.deleteProject);

module.exports = router;
