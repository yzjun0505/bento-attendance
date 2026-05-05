/**
 * 离线打卡管理控制器
 * 无网络时缓存打卡数据，有网后同步
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 提交离线打卡缓存
 * POST /api/offline-checkins
 */
async function submitOfflineCheckin(req, res) {
  try {
    const { type, latitude, longitude, address, photo, remark, project_id, local_timestamp } = req.body;
    const userId = req.user.id;

    if (!type || !local_timestamp) {
      return res.status(400).json(errorResponse('打卡类型和本地时间不能为空', 400));
    }

    const db = getPool();
    const [result] = await db.execute(
      `INSERT INTO offline_checkins (user_id, type, latitude, longitude, address, photo, remark, project_id, local_timestamp)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, type, latitude || null, longitude || null, address || '', photo || '', remark || '', project_id || null, local_timestamp]
    );

    res.json(successResponse({ id: result.insertId }, '离线打卡已缓存'));
  } catch (err) {
    logger.error('离线打卡缓存失败', { error: err.message, userId: req.user?.id });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取当前用户的离线打卡记录
 * GET /api/offline-checkins/mine
 */
async function getMyOfflineCheckins(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      `SELECT * FROM offline_checkins WHERE user_id = ? ORDER BY local_timestamp DESC`,
      [req.user.id]
    );
    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取离线打卡记录失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 同步离线打卡（将缓存数据转为正式打卡）
 * POST /api/offline-checkins/sync
 */
async function syncOfflineCheckins(req, res) {
  try {
    const db = getPool();
    const userId = req.user.id;

    // 获取未同步的离线打卡
    const [offlineRows] = await db.execute(
      `SELECT * FROM offline_checkins WHERE user_id = ? AND synced = 0 ORDER BY local_timestamp ASC`,
      [userId]
    );

    if (offlineRows.length === 0) {
      return res.json(successResponse({ synced: 0, failed: 0 }, '没有待同步的离线打卡'));
    }

    let synced = 0;
    let failed = 0;

    for (const oc of offlineRows) {
      try {
        // 写入正式打卡表
        await db.execute(
          `INSERT INTO checkins (user_id, project_id, type, latitude, longitude, address, photo, remark, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [oc.user_id, oc.project_id, oc.type, oc.latitude, oc.longitude, oc.address, oc.photo, oc.remark, oc.local_timestamp]
        );

        // 标记为已同步
        await db.execute(
          'UPDATE offline_checkins SET synced = 1, sync_time = NOW() WHERE id = ?',
          [oc.id]
        );
        synced++;
      } catch (err) {
        logger.warn('同步单条离线打卡失败', { error: err.message, offlineId: oc.id });
        failed++;
      }
    }

    res.json(successResponse({ synced, failed, total: offlineRows.length }, `同步完成：成功 ${synced} 条，失败 ${failed} 条`));
  } catch (err) {
    logger.error('同步离线打卡失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取所有离线打卡（管理端）
 * GET /api/offline-checkins
 */
async function getAllOfflineCheckins(req, res) {
  try {
    const db = getPool();
    const { user_id, synced } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (user_id) {
      where += ' AND oc.user_id = ?';
      params.push(parseInt(user_id));
    }
    if (synced !== undefined && synced !== '') {
      where += ' AND oc.synced = ?';
      params.push(parseInt(synced));
    }

    const [rows] = await db.execute(
      `SELECT oc.*, u.name as user_name, u.username
       FROM offline_checkins oc
       JOIN users u ON oc.user_id = u.id
       ${where}
       ORDER BY oc.local_timestamp DESC`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取离线打卡列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { submitOfflineCheckin, getMyOfflineCheckins, syncOfflineCheckins, getAllOfflineCheckins };
