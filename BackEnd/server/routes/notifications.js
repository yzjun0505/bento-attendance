/**
 * 消息通知路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const notificationController = require('../controllers/notificationController');

router.use(authMiddleware);

router.get('/', notificationController.getNotifications);
router.get('/all', adminOnly, notificationController.getAllNotifications);
router.get('/unread-count', notificationController.getUnreadNotificationCount);
router.post('/', adminOnly, notificationController.createNotification);
router.put('/:id/read', notificationController.markNotificationAsRead);
router.put('/read-all', notificationController.markAllNotificationsAsRead);
router.delete('/:id', notificationController.deleteNotification);

module.exports = router;
