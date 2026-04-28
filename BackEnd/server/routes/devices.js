const express = require('express');
const router = express.Router();
const deviceController = require('../controllers/deviceController');
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');

// 权限控制：只有系统管理员(admin)与项目经理(manager)可以进行设备管理
router.use(authMiddleware);
router.use(managerOrAdmin);

// 获取设备列表
router.get('/', deviceController.getDevices);

// 创建设备
router.post('/', deviceController.createDevice);

// 更新设备状态与详情
router.put('/:id', deviceController.updateDevice);

// 删除设备
router.delete('/:id', deviceController.deleteDevice);

module.exports = router;
