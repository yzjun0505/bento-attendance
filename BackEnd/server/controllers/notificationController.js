/**
 * 消息通知控制器
 */
const notificationService = require('../services/notificationService');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const { getPool } = require('../models/db');

/**
 * 获取当前用户的消息列表
 * GET /api/notifications
 */
async function getNotifications(req, res) {
  try {
    const user_id = req.user.id;
    const { page, pageSize } = parsePagination(req.query);
    const { type, is_read } = req.query;

    const result = await notificationService.getUserNotifications(user_id, {
      page,
      pageSize,
      type,
      is_read
    });

    res.json(successResponse(result));
  } catch (err) {
    console.error('获取消息列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 标记消息为已读
 * PUT /api/notifications/:id/read
 */
async function markNotificationAsRead(req, res) {
  try {
    const user_id = req.user.id;
    const notification_id = req.params.id;

    const success = await notificationService.markAsRead(notification_id, user_id);

    if (!success) {
      return res.status(404).json(errorResponse('消息不存在或无权限', 404));
    }

    res.json(successResponse(null, '消息已标记为已读'));
  } catch (err) {
    console.error('标记消息已读失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 标记所有消息为已读
 * PUT /api/notifications/read-all
 */
async function markAllNotificationsAsRead(req, res) {
  try {
    const user_id = req.user.id;
    const count = await notificationService.markAllAsRead(user_id);

    res.json(successResponse({ count }, `已标记 ${count} 条消息为已读`));
  } catch (err) {
    console.error('标记所有消息已读失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取未读消息数量
 * GET /api/notifications/unread-count
 */
async function getUnreadNotificationCount(req, res) {
  try {
    const user_id = req.user.id;
    const { type } = req.query;

    const count = await notificationService.getUnreadCount(user_id, type);

    res.json(successResponse({ count }));
  } catch (err) {
    console.error('获取未读消息数失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除消息
 * DELETE /api/notifications/:id
 */
async function deleteNotification(req, res) {
  try {
    const user_id = req.user.id;
    const user_role = req.user.role;
    const notification_id = req.params.id;

    // 管理员可以删除任何通知，普通用户只能删除自己的
    const success = await notificationService.deleteNotification(notification_id, user_id, user_role === 'admin');

    if (!success) {
      return res.status(404).json(errorResponse('消息不存在或无权限', 404));
    }

    res.json(successResponse(null, '消息已删除'));
  } catch (err) {
    console.error('删除消息失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function createNotification(req, res) {
  try {
    const { title, content, type = 'system', user_id = null } = req.body;

    if (!title || !content) {
      return res.status(400).json(errorResponse('标题和内容不能为空', 400));
    }

    const validTypes = ['system', 'checkin', 'project', 'alert'];
    if (!validTypes.includes(type)) {
      return res.status(400).json(errorResponse('无效的消息类型', 400));
    }

    if (user_id) {
      const insertId = await notificationService.createNotification({
        user_id,
        title,
        content,
        type
      });
      const [rows] = await getPool().execute(
        'SELECT id, user_id, title, content, type, is_read, created_at FROM notifications WHERE id = ?',
        [insertId]
      );
      res.json(successResponse(rows[0], '通知发送成功'));
    } else {
      const db = getPool();
      const [activeUsers] = await db.execute(
        'SELECT id FROM users WHERE status = 1'
      );
      const user_ids = activeUsers.map(u => u.id);

      if (user_ids.length === 0) {
        return res.status(400).json(errorResponse('没有活跃用户', 400));
      }

      await notificationService.createNotificationForUsers(user_ids, {
        title,
        content,
        type
      });

      const [rows] = await db.execute(
        'SELECT id, user_id, title, content, type, is_read, created_at FROM notifications WHERE title = ? AND content = ? AND type = ? ORDER BY created_at DESC LIMIT ?',
        [title, content, type, user_ids.length]
      );

      res.json(successResponse(rows, `已向 ${user_ids.length} 位用户发送通知`));
    }
  } catch (err) {
    console.error('创建通知失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取所有通知列表（管理员）
 * GET /api/notifications/all
 */
async function getAllNotifications(req, res) {
  try {
    const { page, pageSize } = parsePagination(req.query);
    const { type } = req.query;
    const db = getPool();

    let where = '';
    const params = [];

    if (type) {
      where = 'WHERE type = ?';
      params.push(type);
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM notifications ${where}`,
      params
    );
    const total = countRows[0].total;

    const offset = (page - 1) * pageSize;
    const [rows] = await db.query(
      `SELECT n.id, n.title, n.content, n.type, n.is_read, n.created_at, n.user_id, u.name as user_name
       FROM notifications n
       LEFT JOIN users u ON n.user_id = u.id
       ${where}
       ORDER BY n.created_at DESC
       LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({
      list: rows,
      total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取通知列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = {
  getNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  getUnreadNotificationCount,
  deleteNotification,
  createNotification,
  getAllNotifications
};
