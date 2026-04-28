/**
 * IM 相关路由（OpenIM）
 */
const express = require('express');
const router = express.Router();

const { authMiddleware } = require('../middleware/auth');
const imConversationController = require('../controllers/imConversationController');

router.use(authMiddleware);

// 会话
router.get('/conversations', imConversationController.getConversations);
router.get('/conversations/seqs', imConversationController.getConversationSeqs);
router.put('/conversations/:conversationID/read', imConversationController.markConversationRead);
router.put('/conversations/:conversationID/pin', imConversationController.setConversationPin);

module.exports = router;

