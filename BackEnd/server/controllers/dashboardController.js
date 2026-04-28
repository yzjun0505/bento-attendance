/**
 * 数据看板控制器
 * 
 * 修复点：
 * 1. type 兼容 'in'/'clock_in'/'out'/'clock_out'
 * 2. 时区使用 getTodayRange（本地时间）
 * 3. 迟到判断使用考勤组 work_start_time 而非硬编码 09:00
 * 4. 在线人数 = 2小时内有位置上报的用户数（基于 locations 表，不依赖打卡）
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, getTodayRange } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 获取看板统计数据
 * GET /api/dashboard/stats
 */
async function getStats(req, res) {
  try {
    const db = getPool();
    const { start, end } = getTodayRange();

    // 今日出勤总人数（上班打卡去重）
    const [attendanceRows] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total 
       FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in') AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 当前在线人数：优先用 locations 表（2小时内有位置上报）
    // 降级：如果 locations 表无数据，用 checkins 表（今天有打卡的用户）
    let onlineCount = 0;
    try {
      const [locRows] = await db.execute(
        `SELECT COUNT(DISTINCT l.user_id) as total
         FROM locations l
         INNER JOIN users u ON l.user_id = u.id
         WHERE u.status = 1 AND l.created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)`
      );
      onlineCount = locRows[0].total;
    } catch (err) {
      logger.warn('在线人数统计（locations表）失败，将降级使用checkins表', { error: err.message });
    }

    // 如果 locations 表无在线记录，降级用 checkins 表
    if (onlineCount === 0) {
      try {
        const [checkinRows] = await db.execute(
          `SELECT COUNT(DISTINCT user_id) as total
           FROM checkins
           WHERE created_at >= ? AND created_at < ?`,
          [start, end]
        );
        onlineCount = checkinRows[0].total;
      } catch (err) {
        logger.warn('在线人数统计（checkins表降级）失败', { error: err.message });
      }
    }

    // 异常打卡数（围栏外的上下班打卡）
    const [abnormalRows] = await db.execute(
      `SELECT COUNT(*) as total FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in' OR type = 'out' OR type = 'clock_out') 
         AND is_outside = 1 AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 活跃工程项目数
    const [projectRows] = await db.execute(
      `SELECT COUNT(DISTINCT project_id) as total FROM checkins WHERE created_at >= ? AND created_at < ? AND project_id IS NOT NULL`,
      [start, end]
    );

    // 昨天出勤总人数
    const yesterdayStart = new Date(start);
    yesterdayStart.setDate(yesterdayStart.getDate() - 1);
    const yesterdayEnd = new Date(end);
    yesterdayEnd.setDate(yesterdayEnd.getDate() - 1);

    const [yesterdayAttendanceRows] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total 
       FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in') AND created_at >= ? AND created_at < ?`,
      [yesterdayStart, yesterdayEnd]
    );
    const yesterdayAttendance = yesterdayAttendanceRows[0].total;

    // 出勤人数环比变化
    let attendanceChangePercent = 0;
    if (yesterdayAttendance > 0) {
      attendanceChangePercent = ((attendanceRows[0].total - yesterdayAttendance) / yesterdayAttendance) * 100;
    } else if (attendanceRows[0].total > 0) {
      attendanceChangePercent = 100;
    }

    res.json(successResponse({
      totalAttendance: attendanceRows[0].total,
      yesterdayAttendance,
      attendanceChangePercent: parseFloat(attendanceChangePercent.toFixed(1)),
      currentOnline: onlineCount,
      abnormalCount: abnormalRows[0].total,
      activeProjects: projectRows[0].total
    }));
  } catch (err) {
    logger.error('获取看板统计失败', { error: err.message, stack: err.stack });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取出勤趋势
 * GET /api/dashboard/trend?days=7
 */
async function getTrend(req, res) {
  try {
    const db = getPool();
    const days = parseInt(req.query.days) || 7;
    const dates = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const pad = (n) => String(n).padStart(2, '0');
      dates.push(`${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`);
    }

    const startDate = dates[0] + ' 00:00:00';
    const endDateCalc = new Date(dates[dates.length - 1]);
    endDateCalc.setDate(endDateCalc.getDate() + 1);
    const pad = (n) => String(n).padStart(2, '0');
    const endDateStr = `${endDateCalc.getFullYear()}-${pad(endDateCalc.getMonth() + 1)}-${pad(endDateCalc.getDate())} 00:00:00`;

    const [rows] = await db.query(
      `SELECT DATE(c.created_at) as date, p.name as projectName, c.project_id, COUNT(DISTINCT c.user_id) as count
       FROM checkins c
       LEFT JOIN projects p ON c.project_id = p.id
       WHERE (c.type = 'in' OR c.type = 'clock_in') AND c.created_at >= ? AND c.created_at < ?
       GROUP BY DATE(c.created_at), c.project_id, p.name
       ORDER BY date ASC`,
      [startDate, endDateStr]
    );

    // 获取每个项目的预期打卡人数（在职用户数）
    const [userRows] = await db.query(
      `SELECT project_id, COUNT(id) as expectedCount 
       FROM users 
       WHERE status = 1 
       GROUP BY project_id`
    );

    const expectedCountMap = {};
    for (const r of userRows) {
      const key = r.project_id === null ? 'null' : String(r.project_id);
      expectedCountMap[key] = r.expectedCount;
    }

    const result = rows.map(r => {
      const key = r.project_id === null ? 'null' : String(r.project_id);
      return {
        date: r.date instanceof Date ? 
          `${r.date.getFullYear()}-${String(r.date.getMonth()+1).padStart(2,'0')}-${String(r.date.getDate()).padStart(2,'0')}` : 
          String(r.date),
        projectName: r.projectName || '未分配项目',
        count: r.count,
        expectedCount: expectedCountMap[key] || 0
      };
    });

    res.json(successResponse(result));
  } catch (err) {
    logger.error('获取趋势数据失败', { error: err.message, stack: err.stack });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取今日打卡状态分布
 * GET /api/dashboard/distribution
 * 
 * 分正常/迟到/请假/未打卡
 * 迟到判断：使用考勤组的 work_start_time
 */
async function getDistribution(req, res) {
  try {
    const db = getPool();
    const { start, end } = getTodayRange();

    // 获取所有启用用户数
    const [totalUsers] = await db.execute(
      'SELECT COUNT(*) as total FROM users WHERE status = 1'
    );

    // 获取考勤组默认上班时间（取第一个启用的考勤组）
    const [groupRows] = await db.execute(
      `SELECT work_start_time FROM attendance_groups WHERE status = 1 ORDER BY id LIMIT 1`
    );
    const defaultStartTime = groupRows.length > 0 ? groupRows[0].work_start_time : '09:00:00';

    // 今日上班打卡（围栏内）的人数
    const [normalRows] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total 
       FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in') AND is_outside = 0 AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 迟到人数：上班打卡时间晚于考勤组规定上班时间
    const [lateRows] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total 
       FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in') AND is_outside = 0 
         AND TIME(created_at) > ? AND created_at >= ? AND created_at < ?`,
      [defaultStartTime, start, end]
    );

    // 围栏外打卡（也算异常，归入迟到或单独统计）
    const [outsideRows] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total 
       FROM checkins 
       WHERE (type = 'in' OR type = 'clock_in') AND is_outside = 1 AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    const checkedIn = normalRows[0].total + outsideRows[0].total;
    const late = lateRows[0].total;
    const normal = checkedIn - late;
    const absent = Math.max(0, totalUsers[0].total - checkedIn);

    res.json(successResponse({
      normal: Math.max(0, normal),
      late,
      leave: 0,  // 暂无请假系统
      absent
    }));
  } catch (err) {
    logger.error('获取分布数据失败', { error: err.message, stack: err.stack });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取异常打卡预警
 * GET /api/dashboard/anomalies?limit=5
 */
async function getAnomalies(req, res) {
  try {
    const db = getPool();
    const limit = Math.min(parseInt(req.query.limit) || 5, 20);

    // 获取考勤组默认上班时间
    const [groupRows] = await db.execute(
      `SELECT work_start_time FROM attendance_groups WHERE status = 1 ORDER BY id LIMIT 1`
    );
    const defaultStartTime = groupRows.length > 0 ? groupRows[0].work_start_time : '09:00:00';

    const [rows] = await db.query(
      `SELECT c.id, u.name as userName, p.name as projectName,
              CASE
                WHEN c.is_outside = 1 THEN '围栏外打卡'
                WHEN TIME(c.created_at) > ? THEN '迟到打卡'
                ELSE '异常打卡'
              END as anomalyType,
              c.created_at as time
       FROM checkins c
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN projects p ON c.project_id = p.id
       WHERE (c.type = 'in' OR c.type = 'clock_in')
         AND (c.is_outside = 1 OR TIME(c.created_at) > ?)
       ORDER BY c.created_at DESC
       LIMIT ${limit}`,
      [defaultStartTime, defaultStartTime]
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取异常记录失败', { error: err.message, stack: err.stack });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取待办事项
 * GET /api/dashboard/todos
 */
async function getTodos(req, res) {
  try {
    const db = getPool();
    
    // 获取待审批的申请
    const [pendingAppeals] = await db.execute(
      `SELECT a.id, a.type, a.reason, a.start_date, a.end_date, a.created_at, u.name as userName 
       FROM approval_requests a 
       LEFT JOIN users u ON a.user_id = u.id 
       WHERE a.status = 'pending' 
       ORDER BY a.created_at DESC 
       LIMIT 10`
    );

    // 获取待审批总数
    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM approval_requests WHERE status = 'pending'`
    );

    res.json(successResponse({
      pendingAppeals,
      pendingAppealsCount: countRows[0].total
    }));
  } catch (err) {
    logger.error('获取待办事项失败', { error: err.message, stack: err.stack });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getStats, getTrend, getDistribution, getAnomalies, getTodos };
