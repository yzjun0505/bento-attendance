/**
 * IM 会话控制器（OpenIM）
 */
const openIMService = require('../services/openimService');
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

    const result = await openIMService.getSortedConversationList({
      userID,
      pageNumber,
      showNumber,
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || 'OpenIM 服务异常', 502));
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

    const result = await openIMService.getConversationsHasReadAndMaxSeq({
      userID,
      returnPinned,
    });
    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || 'OpenIM 服务异常', 502));
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
    let { hasReadSeq } = req.body || {};

    // 没传 hasReadSeq，则先拉取 maxSeq，再标记为已读
    if (!hasReadSeq) {
      const seqResult = await openIMService.getConversationsHasReadAndMaxSeq({
        userID,
        conversationIDs: [conversationID],
        returnPinned: false,
      });
      if (!seqResult.success) {
        return res.status(502).json(errorResponse(seqResult.message || 'OpenIM 服务异常', 502));
      }
      const seqInfo = seqResult.data?.seqs?.[conversationID] || seqResult.data?.Seqs?.[conversationID];
      // OpenIM 返回字段在不同版本可能有大小写差异，这里兼容一下
      hasReadSeq = seqInfo?.maxSeq ?? seqInfo?.MaxSeq ?? 0;
    }

    const result = await openIMService.markConversationAsRead({
      userID,
      conversationID,
      hasReadSeq: Number(hasReadSeq) || 0,
      seqs: [],
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || 'OpenIM 服务异常', 502));
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
    if (!conversationType) {
      return res.status(400).json(errorResponse('conversationType 必填（1单聊/2群聊等）', 400));
    }

    const result = await openIMService.setConversations({
      operatorUserID,
      userIDs: [operatorUserID.toString()],
      conversation: {
        conversationID,
        conversationType: Number(conversationType),
        userID: userID || '',
        groupID: groupID || '',
        isPinned,
      },
    });

    if (!result.success) {
      return res.status(502).json(errorResponse(result.message || 'OpenIM 服务异常', 502));
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

