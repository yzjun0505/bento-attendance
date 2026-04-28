/**
 * 考勤组管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const attendanceGroupController = require('../controllers/attendanceGroupController');

router.use(authMiddleware);

router.get('/', attendanceGroupController.getGroups);
router.get('/my', attendanceGroupController.getMyGroup);
router.get('/:id', attendanceGroupController.getGroupById);
router.post('/', adminOnly, attendanceGroupController.createGroup);
router.put('/:id', adminOnly, attendanceGroupController.updateGroup);
router.delete('/:id', adminOnly, attendanceGroupController.deleteGroup);
router.post('/:id/members', adminOnly, attendanceGroupController.addMembers);
router.delete('/:id/members/:userId', adminOnly, attendanceGroupController.removeMember);

module.exports = router;
