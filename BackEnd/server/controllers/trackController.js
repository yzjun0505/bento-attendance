/**
 * 轨迹回放控制器
 * 查看某人一天的位置路线
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 获取某人某天的轨迹
 * GET /api/tracks/:userId?date=2024-01-01
 */
async function getTrack(req, res) {
  try {
    const userId = req.params.userId;
    const { date } = req.query;

    if (!date) {
      return res.status(400).json(errorResponse('日期参数不能为空', 400));
    }

    const db = getPool();

    // 获取当天的位置记录（locations表）
    const [locationRows] = await db.execute(
      `SELECT id, latitude, longitude, accuracy, speed, address, created_at,
        'location' as source
       FROM locations
       WHERE user_id = ? AND DATE(created_at) = ?
       ORDER BY created_at ASC`,
      [userId, date]
    );

    // 获取当天的打卡记录（checkins表，带位置信息）
    const [checkinRows] = await db.execute(
      `SELECT id, latitude, longitude, address, type, photo, remark, created_at,
        'checkin' as source
       FROM checkins
       WHERE user_id = ? AND DATE(created_at) = ? AND latitude IS NOT NULL
       ORDER BY created_at ASC`,
      [userId, date]
    );

    // 合并并按时间排序
    const allPoints = [...locationRows, ...checkinRows].sort((a, b) => {
      return new Date(a.created_at) - new Date(b.created_at);
    });

    // 计算轨迹统计
    let totalDistance = 0;
    let stayPoints = [];
    let currentStay = null;

    for (let i = 0; i < allPoints.length; i++) {
      const point = allPoints[i];

      // 计算与上一点的距离
      if (i > 0) {
        const prev = allPoints[i - 1];
        const dist = calculateDistance(
          prev.latitude, prev.longitude,
          point.latitude, point.longitude
        );
        totalDistance += dist;

        // 检测停留点（距离小于50米且时间间隔大于5分钟）
        if (dist < 50) {
          if (!currentStay) {
            currentStay = {
              start: prev.created_at,
              end: point.created_at,
              latitude: point.latitude,
              longitude: point.longitude,
              address: point.address,
              duration: 0
            };
          } else {
            currentStay.end = point.created_at;
          }
        } else {
          if (currentStay) {
            const duration = (new Date(currentStay.end) - new Date(currentStay.start)) / 1000 / 60;
            if (duration >= 5) {
              currentStay.duration = Math.round(duration);
              stayPoints.push(currentStay);
            }
            currentStay = null;
          }
        }
      }
    }

    // 处理最后一个停留点
    if (currentStay) {
      const duration = (new Date(currentStay.end) - new Date(currentStay.start)) / 1000 / 60;
      if (duration >= 5) {
        currentStay.duration = Math.round(duration);
        stayPoints.push(currentStay);
      }
    }

    // 获取用户信息
    const [userRows] = await db.execute(
      'SELECT id, name, username, avatar FROM users WHERE id = ?',
      [userId]
    );

    res.json(successResponse({
      user: userRows[0] || null,
      date,
      total_points: allPoints.length,
      total_distance: Math.round(totalDistance),
      stay_points: stayPoints,
      track: allPoints.map(p => ({
        id: p.id,
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        address: p.address,
        source: p.source,
        type: p.type || null,
        photo: p.photo || null,
        remark: p.remark || null,
        time: p.created_at
      }))
    }));
  } catch (err) {
    logger.error('获取轨迹失败', { error: err.message, userId: req.params.userId });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取轨迹热力图数据（某区域内所有用户的活动密度）
 * GET /api/tracks/heatmap?date_start=&date_end=&project_id=
 */
async function getHeatmap(req, res) {
  try {
    const { date_start, date_end, project_id } = req.query;
    const db = getPool();

    let where = 'WHERE l.latitude IS NOT NULL AND l.longitude IS NOT NULL';
    const params = [];

    if (date_start) {
      where += ' AND l.created_at >= ?';
      params.push(date_start);
    }
    if (date_end) {
      where += ' AND l.created_at <= ?';
      params.push(date_end);
    }
    if (project_id) {
      where += ' AND u.project_id = ?';
      params.push(parseInt(project_id));
    }

    const [rows] = await db.execute(
      `SELECT l.latitude, l.longitude, l.created_at, u.name as user_name
       FROM locations l
       JOIN users u ON l.user_id = u.id
       ${where}
       ORDER BY l.created_at DESC
       LIMIT 5000`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取热力图数据失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 计算两点间距离（Haversine公式，单位米）
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

module.exports = { getTrack, getHeatmap };
