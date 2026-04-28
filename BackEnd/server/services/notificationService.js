/**
 * 通知服务 - MySQL 存储 +（可选）OpenIM 实时推送
 */
const openIMService = require('./openimService');
const { getPool } = require('../models/db');

const IM_SENDER_ID = process.env.OPENIM_ADMIN_USERID || 'imAdmin';

class NotificationService {
  static async getUserNotifications(userId, { page = 1, pageSize = 20, type, is_read } = {}) {
    const db = getPool();
    const where = ['user_id = ?'];
    const params = [Number(userId)];

    if (type) {
      where.push('type = ?');
      params.push(type);
    }

    if (is_read !== undefined && is_read !== null && is_read !== '') {
      where.push('is_read = ?');
      params.push(Number(is_read));
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const offset = (Number(page) - 1) * Number(pageSize);

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM notifications ${whereSql}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT id, user_id, title, content, type, is_read, created_at
       FROM notifications
       ${whereSql}
       ORDER BY created_at DESC
       LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    return { list: rows, total, page: Number(page), pageSize: Number(pageSize) };
  }

  static async createNotification({ user_id, title, content, type = 'system' }) {
    const db = getPool();
    const [result] = await db.execute(
      `INSERT INTO notifications (user_id, title, content, type, is_read)
       VALUES (?, ?, ?, ?, 0)`,
      [Number(user_id), title, content, type]
    );

    // 实时推送：失败不影响主流程
    openIMService
      .sendMessage({
        recvID: String(user_id),
        sendID: IM_SENDER_ID,
        content: `【${title}】${content}`,
        contentType: 101,
      })
      .catch((err) => console.warn('OpenIM 推送通知失败(忽略):', err.message));

    return result.insertId;
  }

  static async createNotificationForUsers(userIds, { title, content, type = 'system' }) {
    const db = getPool();
    if (!Array.isArray(userIds) || userIds.length === 0) return 0;

    const values = userIds.map((uid) => [Number(uid), title, content, type, 0]);
    const placeholders = values.map(() => '(?, ?, ?, ?, ?)').join(',');
    const flat = values.flat();

    const [result] = await db.execute(
      `INSERT INTO notifications (user_id, title, content, type, is_read) VALUES ${placeholders}`,
      flat
    );

    // 批量推送：异步/尽力而为，避免阻塞
    Promise.allSettled(
      userIds.map((uid) =>
        openIMService.sendMessage({
          recvID: String(uid),
          sendID: IM_SENDER_ID,
          content: `【${title}】${content}`,
          contentType: 101,
        })
      )
    ).then(() => {});

    return result.affectedRows || 0;
  }

  static async markAsRead(notificationId, userId) {
    const db = getPool();
    const [result] = await db.execute(
      `UPDATE notifications SET is_read = 1
       WHERE id = ? AND user_id = ?`,
      [Number(notificationId), Number(userId)]
    );
    return result.affectedRows > 0;
  }

  static async markAllAsRead(userId) {
    const db = getPool();
    const [result] = await db.execute(
      `UPDATE notifications SET is_read = 1
       WHERE user_id = ? AND is_read = 0`,
      [Number(userId)]
    );
    return result.affectedRows || 0;
  }

  static async getUnreadCount(userId, type) {
    const db = getPool();
    const where = ['user_id = ?', 'is_read = 0'];
    const params = [Number(userId)];
    if (type) {
      where.push('type = ?');
      params.push(type);
    }
    const [rows] = await db.execute(
      `SELECT COUNT(*) as count FROM notifications WHERE ${where.join(' AND ')}`,
      params
    );
    return rows[0].count;
  }

  static async deleteNotification(notificationId, userId, isAdmin = false) {
    const db = getPool();
    if (isAdmin) {
      const [result] = await db.execute(`DELETE FROM notifications WHERE id = ?`, [Number(notificationId)]);
      return result.affectedRows > 0;
    }
    const [result] = await db.execute(
      `DELETE FROM notifications WHERE id = ? AND user_id = ?`,
      [Number(notificationId), Number(userId)]
    );
    return result.affectedRows > 0;
  }
}

module.exports = NotificationService;
