/**
 * 节假日管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const holidayController = require('../controllers/holidayController');

router.use(authMiddleware);

router.get('/', holidayController.getHolidays);
router.get('/check', holidayController.checkDate);
router.post('/', adminOnly, holidayController.createHoliday);
router.post('/batch', adminOnly, holidayController.batchCreateHolidays);
router.put('/:id', adminOnly, holidayController.updateHoliday);
router.delete('/:id', adminOnly, holidayController.deleteHoliday);

module.exports = router;
