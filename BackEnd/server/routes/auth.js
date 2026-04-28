/**
 * 认证路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const authController = require('../controllers/authController');

// 公开路由
router.post('/login', authController.login);
router.post('/register', authController.register);

// 需要登录
router.get('/profile', authMiddleware, authController.getProfile);
router.put('/password', authMiddleware, authController.changePassword);
router.get('/im-token', authMiddleware, authController.getIMToken);

module.exports = router;
