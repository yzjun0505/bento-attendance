/**
 * 审批管理路由
 */
const express = require('express');
const router = express.Router();
const { authMiddleware, managerOrAdmin } = require('../middleware/auth');
const approvalController = require('../controllers/approvalController');

router.use(authMiddleware);

router.post('/', approvalController.createApproval);
router.get('/pending', managerOrAdmin, approvalController.getPendingApprovals);
router.get('/mine', approvalController.getMyApprovals);
router.get('/all', managerOrAdmin, approvalController.getAllApprovals);
router.get('/:id', approvalController.getApprovalById);
router.put('/:id/approve', managerOrAdmin, approvalController.approveApproval);
router.put('/:id/reject', managerOrAdmin, approvalController.rejectApproval);
router.delete('/:id', approvalController.deleteApproval);

module.exports = router;
