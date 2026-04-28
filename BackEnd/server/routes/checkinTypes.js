/**
 * 打卡类型路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const checkinTypeController = require('../controllers/checkinTypeController');

router.use(authMiddleware);

// 移动端/通用：获取启用的打卡类型列表
router.get('/', checkinTypeController.getCheckinTypes);

// 管理端：获取所有打卡类型（含停用），分页
router.get('/all', managerOrAdmin, checkinTypeController.getAllCheckinTypes);

// 管理端：创建打卡类型
router.post('/', managerOrAdmin, checkinTypeController.createCheckinType);

// 管理端：更新打卡类型
router.put('/:id', managerOrAdmin, checkinTypeController.updateCheckinType);

// 管理端：删除打卡类型
router.delete('/:id', managerOrAdmin, checkinTypeController.deleteCheckinType);

module.exports = router;
