const aiChatService = require('../services/ai/aiChatService');
const { successResponse, errorResponse } = require('../utils/helpers');

function handleError(res, err, fallback = 'AI 助手服务异常') {
  const status = err.status || 500;
  res.status(status).json(errorResponse(err.message || fallback, status));
}

async function chat(req, res) {
  try {
    const result = await aiChatService.chat({
      user: req.user,
      message: req.body.message,
      context: req.body.context || {},
      conversationId: req.body.conversationId,
    });
    res.json(successResponse(result));
  } catch (err) {
    handleError(res, err);
  }
}

async function listConversations(req, res) {
  try {
    const result = await aiChatService.listConversations(req.user);
    res.json(successResponse(result));
  } catch (err) {
    handleError(res, err);
  }
}

async function getMessages(req, res) {
  try {
    const result = await aiChatService.getMessages(req.user, req.params.id);
    res.json(successResponse(result));
  } catch (err) {
    handleError(res, err);
  }
}

async function deleteConversation(req, res) {
  try {
    const ok = await aiChatService.deleteConversation(req.user, req.params.id);
    if (!ok) {
      return res.status(404).json(errorResponse('会话不存在或无权限', 404));
    }
    res.json(successResponse(null, '会话已删除'));
  } catch (err) {
    handleError(res, err);
  }
}

async function confirmAction(req, res) {
  try {
    const result = await aiChatService.confirmAction({
      user: req.user,
      actionId: req.params.id,
      ipAddress: req.ip,
    });
    res.json(successResponse(result, result.result?.message || '操作已确认'));
  } catch (err) {
    handleError(res, err);
  }
}

function getSuggestions(req, res) {
  const result = aiChatService.suggestions(req.query || {});
  res.json(successResponse(result));
}

module.exports = {
  chat,
  listConversations,
  getMessages,
  deleteConversation,
  confirmAction,
  getSuggestions,
};
