/**
 * 用户管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const userController = require('../controllers/userController');

router.use(authMiddleware);

router.get('/me', userController.getCurrentUser);
router.put('/me', userController.updateCurrentUser);
router.put('/me/password', userController.changePassword);
router.get('/lookup', userController.lookupUser);
router.get('/', managerOrAdmin, userController.getUsers);
router.get('/:id', managerOrAdmin, userController.getUserById);
router.post('/', managerOrAdmin, userController.createUser);
router.put('/:id', managerOrAdmin, userController.updateUser);
router.delete('/:id', managerOrAdmin, userController.deleteUser);
router.put('/:id/reset-password', managerOrAdmin, userController.resetPassword);

module.exports = router;
