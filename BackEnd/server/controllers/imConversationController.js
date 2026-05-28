/**
 * IM 会话控制器（腾讯云 IM）
 */
const tencentIMService = require('../services/tencentImService');
const { successResponse, errorResponse } = require('../utils/helpers');

/**
 * 获取会话列表（排序：置顶优先 + 最后消息时间倒序）
 * GET /api/im/conversations?page=1&pageSize=20
 */
async function getConversations(req, res) {
  try {
    const userID = req.user.id;
    const pageNumber = Number(req.query.page || 1);
    const showNumber = Number(req.query.pageSize || 20);

    const result = await tencentIMService.getSortedConversationList({
      userID,
      pageNumber,
      showNumber,
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || '腾讯云 IM 服务异常', 502));
    }
    return res.json(successResponse(result.data));
  } catch (err) {
    console.error('获取会话列表失败:', err);
    return res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取会话 hasReadSeq/maxSeq（用于未读、清除未读）
 * GET /api/im/conversations/seqs?returnPinned=true
 */
async function getConversationSeqs(req, res) {
  try {
    const userID = req.user.id;
    const returnPinned = String(req.query.returnPinned || 'false') === 'true';

    const result = await tencentIMService.getConversationsHasReadAndMaxSeq({
      userID,
      returnPinned,
    });
    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || '腾讯云 IM 服务异常', 502));
    }
    return res.json(successResponse(result.data));
  } catch (err) {
    console.error('获取会话 seq 失败:', err);
    return res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 标记某个会话为已读（清空未读数）
 * PUT /api/im/conversations/:conversationID/read
 * body: { hasReadSeq?: number }
 */
async function markConversationRead(req, res) {
  try {
    const userID = req.user.id;
    const conversationID = req.params.conversationID;
    let { hasReadSeq, peerAccount } = req.body || {};

    if (!hasReadSeq) {
      const seqResult = await tencentIMService.getConversationsHasReadAndMaxSeq({
        userID,
        conversationIDs: [conversationID],
        returnPinned: false,
      });
      if (!seqResult.success) {
        return res.status(502).json(errorResponse(seqResult.message || '腾讯云 IM 服务异常', 502));
      }
      const seqInfo = seqResult.data?.seqs?.[conversationID];
      hasReadSeq = seqInfo?.maxSeq ?? 0;
    }

    const result = await tencentIMService.markConversationAsRead({
      userID,
      peerAccount: peerAccount || conversationID,
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || '腾讯云 IM 服务异常', 502));
    }
    return res.json(successResponse(null, '已清除未读'));
  } catch (err) {
    console.error('标记会话已读失败:', err);
    return res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 置顶/取消置顶会话
 * PUT /api/im/conversations/:conversationID/pin
 * body: { isPinned: boolean, conversationType?: number, userID?: string, groupID?: string }
 */
async function setConversationPin(req, res) {
  try {
    const operatorUserID = req.user.id;
    const conversationID = req.params.conversationID;
    const { isPinned, conversationType, userID, groupID } = req.body || {};

    if (typeof isPinned !== 'boolean') {
      return res.status(400).json(errorResponse('isPinned 必须是 boolean', 400));
    }

    const result = await tencentIMService.setConversations({
      operatorUserID,
      userIDs: [operatorUserID.toString()],
      conversation: {
        conversationID,
        conversationType: Number(conversationType) || 1,
        userID: userID || '',
        groupID: groupID || '',
        isPinned,
      },
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || '腾讯云 IM 服务异常', 502));
    }
    return res.json(successResponse(null, '会话设置已更新'));
  } catch (err) {
    console.error('更新会话置顶失败:', err);
    return res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = {
  getConversations,
  getConversationSeqs,
  markConversationRead,
  setConversationPin,
};
