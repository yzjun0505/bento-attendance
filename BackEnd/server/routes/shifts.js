/**
 * 班次管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const shiftController = require('../controllers/shiftController');

router.use(authMiddleware);

router.get('/', shiftController.getShifts);
router.get('/:id', shiftController.getShiftById);
router.post('/', adminOnly, shiftController.createShift);
router.put('/:id', adminOnly, shiftController.updateShift);
router.delete('/:id', adminOnly, shiftController.deleteShift);

module.exports = router;
