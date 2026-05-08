/**
 * 排班管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly, managerOrAdmin } = require('../middleware/auth');
const scheduleController = require('../controllers/scheduleController');

router.use(authMiddleware);

router.get('/', scheduleController.getSchedules);
router.get('/calendar', managerOrAdmin, scheduleController.getCalendar);
router.get('/today', scheduleController.getTodaySchedule);
router.post('/batch', adminOnly, scheduleController.batchSchedule);
router.put('/:id/rest', managerOrAdmin, scheduleController.setRestDay);
router.delete('/:id', adminOnly, scheduleController.deleteSchedule);

module.exports = router;
