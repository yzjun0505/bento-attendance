/**
 * 位置控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const { getAccessibleUserIds } = require('../middleware/authScope');
const logger = require('../utils/logger');

/**
 * 上报位置
 * POST /api/location/report
 */
async function reportLocation(req, res) {
  try {
    const { latitude, longitude, accuracy, speed, address } = req.body;
    if (!latitude || !longitude) {
      return res.status(400).json(errorResponse('经纬度不能为空', 400));
    }

    const db = getPool();
    await db.execute(
      'INSERT INTO locations (user_id, latitude, longitude, accuracy, speed, address) VALUES (?, ?, ?, ?, ?, ?)',
      [req.user.id, latitude, longitude, accuracy || null, speed || null, address || '']
    );

    // 通过 Socket.IO 广播位置更新
    if (req.app.get('io')) {
      req.app.get('io').emit('location:update', {
        user_id: req.user.id,
        user_name: req.user.name,
        latitude,
        longitude,
        accuracy,
        speed,
        address,
        timestamp: new Date().toISOString()
      });
    }

    res.json(successResponse(null, '位置上报成功'));
  } catch (err) {
    logger.error('位置上报失败', { error: err.message, userId: req.user?.id });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取所有人最新位置
 * GET /api/location/latest
 * 
 * 优先返回 locations 表数据（2小时内），如果无数据则降级返回最近打卡位置
 */
async function getLatestLocations(req, res) {
  try {
    const db = getPool();
    const { project_id } = req.query;

    let query = `
      SELECT l.*, u.name as user_name, u.avatar, u.phone, u.project_id, p.name as project_name
      FROM locations l
      INNER JOIN (
        SELECT user_id, MAX(created_at) as max_created_at
        FROM locations
        GROUP BY user_id
      ) latest ON l.user_id = latest.user_id AND l.created_at = latest.max_created_at
      LEFT JOIN users u ON l.user_id = u.id
      LEFT JOIN projects p ON u.project_id = p.id
      WHERE u.status = 1
    `;
    const params = [];

    if (project_id) {
      query += ' AND u.project_id = ?';
      params.push(parseInt(project_id));
    }

    // 只获取最近2小时内有位置上报的用户（视为在线）
    query += ' AND l.created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)';
    query += ' ORDER BY l.created_at DESC';

    let [rows] = await db.execute(query, params);

    // 降级：如果 locations 无数据，用最近打卡的位置
    if (rows.length === 0) {
      let fallbackQuery = `
        SELECT c.user_id, c.latitude, c.longitude, c.address, c.created_at,
               u.name as user_name, u.avatar, u.phone, u.project_id, p.name as project_name
        FROM checkins c
        INNER JOIN (
          SELECT user_id, MAX(id) as max_id FROM checkins 
          WHERE latitude IS NOT NULL AND longitude IS NOT NULL
          GROUP BY user_id
        ) latest ON c.id = latest.max_id
        LEFT JOIN users u ON c.user_id = u.id
        LEFT JOIN projects p ON u.project_id = p.id
        WHERE u.status = 1 AND c.latitude IS NOT NULL AND c.longitude IS NOT NULL
      `;
      const fallbackParams = [];
      if (project_id) {
        fallbackQuery += ' AND u.project_id = ?';
        fallbackParams.push(parseInt(project_id));
      }
      fallbackQuery += ' ORDER BY c.created_at DESC';
      const [fallbackRows] = await db.execute(fallbackQuery, fallbackParams);
      
      // 标记数据来源
      rows = fallbackRows.map(r => ({ ...r, source: 'checkin' }));
    } else {
      rows = rows.map(r => ({ ...r, source: 'location' }));
    }

    res.json(successResponse(rows));
  } catch (err) {
    console.error('获取最新位置失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 查询某用户位置历史
 * GET /api/location/history/:userId
 */
async function getLocationHistory(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { date_start, date_end } = req.query;
    const userId = req.params.userId;

    let where = 'WHERE l.user_id = ?';
    const params = [userId];

    if (date_start) {
      where += ' AND l.created_at >= ?';
      params.push(date_start);
    }
    if (date_end) {
      where += ' AND l.created_at <= ?';
      params.push(date_end);
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM locations l ${where}`,
      params
    );

    const [rows] = await db.execute(
      `SELECT l.*, u.name as user_name FROM locations l
       LEFT JOIN users u ON l.user_id = u.id
       ${where}
       ORDER BY l.created_at DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), Number(offset)]
    );

    res.json(successResponse({
      list: rows,
      total: countRows[0].total,
      page,
      pageSize
    }));
  } catch (err) {
    logger.error('查询位置历史失败', { error: err.message, userId: req.params.userId });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取在线人数统计
 * GET /api/location/online-count
 */
async function getOnlineCount(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(`
      SELECT COUNT(DISTINCT l.user_id) as online_count
      FROM locations l
      INNER JOIN users u ON l.user_id = u.id
      WHERE u.status = 1 AND l.created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)
    `);

    res.json(successResponse({ online: rows[0].online_count }));
  } catch (err) {
    logger.error('获取在线人数失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取团队位置（经理查看自己授权项目下工人的最新位置）
 * GET /api/location/team-locations
 */
async function getTeamLocations(req, res) {
  try {
    const db = getPool();
    const role = req.user.role;

    // 仅经理和管理员可查看团队位置
    if (role === 'worker') {
      return res.status(403).json(errorResponse('无权查看团队位置', 403));
    }

    const userIds = await getAccessibleUserIds(req);
    if (userIds.length === 0) {
      return res.json(successResponse({ locations: [] }));
    }

    // 获取每个人最新一条位置记录
    const placeholders = userIds.map(() => '?').join(',');
    const [rows] = await db.query(`
      SELECT l.user_id, l.latitude, l.longitude, l.accuracy, l.address,
             l.created_at, u.name as user_name, u.role, u.avatar,
             p.id as project_id, p.name as project_name
      FROM (
        SELECT user_id, MAX(created_at) as max_time
        FROM locations
        WHERE user_id IN (${placeholders})
        GROUP BY user_id
      ) latest
      JOIN locations l ON l.user_id = latest.user_id AND l.created_at = latest.max_time
      JOIN users u ON l.user_id = u.id
      LEFT JOIN projects p ON u.project_id = p.id
      ORDER BY u.name
    `, userIds);

    // 过滤掉超过30分钟的旧位置
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
    const activeLocations = rows.filter(r => new Date(r.created_at) > thirtyMinAgo);

    res.json(successResponse({
      locations: activeLocations.map(r => ({
        userId: r.user_id,
        name: r.user_name,
        role: r.role,
        avatar: r.avatar,
        latitude: r.latitude,
        longitude: r.longitude,
        accuracy: r.accuracy,
        address: r.address,
        updatedAt: r.created_at,
        projectId: r.project_id,
        projectName: r.project_name,
      })),
      total: activeLocations.length,
    }));
  } catch (err) {
    logger.error('获取团队位置失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { reportLocation, getLatestLocations, getLocationHistory, getOnlineCount, getTeamLocations };
