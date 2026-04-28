/**
 * 位置路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const locationController = require('../controllers/locationController');

router.use(authMiddleware);

router.post('/report', locationController.reportLocation);
router.get('/latest', managerOrAdmin, locationController.getLatestLocations);
router.get('/online-count', managerOrAdmin, locationController.getOnlineCount);
router.get('/history/:userId', managerOrAdmin, locationController.getLocationHistory);

module.exports = router;
