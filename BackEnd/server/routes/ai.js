const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const aiController = require('../controllers/aiController');

router.use(authMiddleware);

router.post('/chat', aiController.chat);
router.get('/conversations', aiController.listConversations);
router.get('/conversations/:id', aiController.getMessages);
router.delete('/conversations/:id', aiController.deleteConversation);
router.post('/actions/:id/confirm', aiController.confirmAction);
router.get('/suggestions', aiController.getSuggestions);

module.exports = router;
