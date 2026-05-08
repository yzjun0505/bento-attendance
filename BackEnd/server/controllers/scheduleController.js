/**
 * 排班管理控制器
 * 支持按日期给用户分配班次
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 将 Date 格式化为本地日期字符串 YYYY-MM-DD（避免 toISOString 的 UTC 偏移问题）
 */
function formatLocalDate(d) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * 获取用户排班
 * GET /api/schedules?user_id=&date_start=&date_end=
 */
async function getSchedules(req, res) {
  try {
    const db = getPool();
    const { user_id, user_ids, date_start, date_end, month } = req.query;
    const isManager = req.user.role === 'admin' || req.user.role === 'manager';

    let where = 'WHERE 1=1';
    const params = [];

    // 支持单用户或多用户筛选
    if (!isManager) {
      where += ' AND us.user_id = ?';
      params.push(req.user.id);
    } else if (user_id) {
      where += ' AND us.user_id = ?';
      params.push(parseInt(user_id));
    } else if (user_ids) {
      const ids = String(user_ids).split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id));
      if (ids.length > 0) {
        where += ` AND us.user_id IN (${ids.map(() => '?').join(',')})`;
        params.push(...ids);
      }
    }

    // 支持 month=YYYY-MM 快捷查询
    let start = date_start;
    let end = date_end;
    if (month && /^\d{4}-\d{2}$/.test(month)) {
      const [y, m] = month.split('-').map(Number);
      start = `${month}-01`;
      const lastDay = new Date(y, m, 0).getDate();
      end = `${month}-${String(lastDay).padStart(2, '0')}`;
    }

    if (start) {
      where += ' AND us.date >= ?';
      params.push(start);
    }
    if (end) {
      where += ' AND us.date <= ?';
      params.push(end);
    }

    const [rows] = await db.execute(
      `SELECT us.*, s.name as shift_name, s.start_time, s.end_time, s.color,
        u.name as user_name
       FROM user_schedules us
       JOIN shifts s ON us.shift_id = s.id
       JOIN users u ON us.user_id = u.id
       ${where}
       ORDER BY us.date DESC`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取排班失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 批量排班（按日期范围）
 * POST /api/schedules/batch
 */
async function batchSchedule(req, res) {
  try {
    // 兼容前端字段名（start_date/end_date 或 date_start/date_end）
    const user_ids = req.body.user_ids;
    const date_start = req.body.date_start || req.body.start_date;
    const date_end = req.body.date_end || req.body.end_date;
    const shift_id = req.body.shift_id;
    const skip_holidays = req.body.skip_holidays === true;
    const weekend_rest = req.body.weekend_rest === true;
    let rest_dates = req.body.rest_dates || [];

    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return res.status(400).json(errorResponse('请选择用户', 400));
    }
    if (!date_start || !date_end) {
      return res.status(400).json(errorResponse('开始日期和结束日期不能为空', 400));
    }
    if (!shift_id) {
      return res.status(400).json(errorResponse('请选择班次', 400));
    }

    const db = getPool();

    // 验证班次是否存在
    const [shiftRows] = await db.execute('SELECT id FROM shifts WHERE id = ? AND status = 1', [shift_id]);
    if (shiftRows.length === 0) {
      return res.status(400).json(errorResponse('班次不存在或已停用', 400));
    }

    // 根据开关计算 rest_dates
    const start = new Date(date_start + 'T00:00:00');
    const end = new Date(date_end + 'T00:00:00');
    const dateRange = [];
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      dateRange.push(formatLocalDate(d));
    }

    if (weekend_rest) {
      for (const dateStr of dateRange) {
        const dt = new Date(dateStr + 'T00:00:00');
        const day = dt.getDay();
        if ((day === 0 || day === 6) && !rest_dates.includes(dateStr)) {
          rest_dates.push(dateStr);
        }
      }
    }

    if (skip_holidays) {
      const [holidayRows] = await db.execute(
        'SELECT date FROM holidays WHERE date >= ? AND date <= ?',
        [date_start, date_end]
      );
      for (const h of holidayRows) {
        const d = h.date;
        if (typeof d === 'string' && !rest_dates.includes(d)) {
          rest_dates.push(d);
        } else if (d instanceof Date) {
          const ds = formatLocalDate(d);
          if (!rest_dates.includes(ds)) {
            rest_dates.push(ds);
          }
        }
      }
    }

    // 生成日期范围
    const dates = [];
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dateStr = formatLocalDate(d);
      const isRest = rest_dates.includes(dateStr);
      dates.push({ date: dateStr, isRest });
    }

    let inserted = 0;
    let updated = 0;

    for (const userId of user_ids) {
      for (const { date, isRest } of dates) {
        // 使用 INSERT ... ON DUPLICATE KEY UPDATE
        const [result] = await db.execute(
          `INSERT INTO user_schedules (user_id, date, shift_id, is_rest)
           VALUES (?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE shift_id = ?, is_rest = ?`,
          [userId, date, shift_id, isRest ? 1 : 0, shift_id, isRest ? 1 : 0]
        );
        if (result.insertId) {
          inserted++;
        } else {
          updated++;
        }
      }
    }

    res.json(successResponse({ inserted, updated }, '排班成功'));
  } catch (err) {
    logger.error('批量排班失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 设置某天休息/取消休息
 * PUT /api/schedules/:id/rest
 */
async function setRestDay(req, res) {
  try {
    const { is_rest } = req.body;
    const db = getPool();
    await db.execute(
      'UPDATE user_schedules SET is_rest = ? WHERE id = ?',
      [is_rest ? 1 : 0, req.params.id]
    );
    res.json(successResponse(null, is_rest ? '已设为休息日' : '已取消休息日'));
  } catch (err) {
    logger.error('设置休息日失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除排班
 * DELETE /api/schedules/:id
 */
async function deleteSchedule(req, res) {
  try {
    const db = getPool();
    await db.execute('DELETE FROM user_schedules WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '排班删除成功'));
  } catch (err) {
    logger.error('删除排班失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取某天的排班日历（管理端视图）
 * GET /api/schedules/calendar?date=2024-01-01
 */
async function getCalendar(req, res) {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json(errorResponse('日期不能为空', 400));
    }

    const db = getPool();
    const [rows] = await db.execute(
      `SELECT us.*, s.name as shift_name, s.start_time, s.end_time, s.color,
        u.name as user_name, u.username
       FROM user_schedules us
       JOIN shifts s ON us.shift_id = s.id
       JOIN users u ON us.user_id = u.id
       WHERE us.date = ?
       ORDER BY s.sort_order ASC, u.name ASC`,
      [date]
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取排班日历失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取当前用户今日排班（移动端用）
 * GET /api/schedules/today
 */
async function getTodaySchedule(req, res) {
  try {
    const userId = req.user.id;
    const db = getPool();

    const today = formatLocalDate(new Date());

    const [rows] = await db.execute(
      `SELECT us.*, s.name as shift_name, s.start_time, s.end_time, s.late_tolerance, s.early_leave_tolerance, s.color
       FROM user_schedules us
       JOIN shifts s ON us.shift_id = s.id
       WHERE us.user_id = ? AND us.date = ? AND us.is_rest = 0`,
      [userId, today]
    );

    if (rows.length === 0) {
      // 如果没有排班，返回默认考勤组的时间
      const [groupRows] = await db.execute(
        `SELECT ag.*, ag.work_start_time as start_time, ag.work_end_time as end_time
         FROM attendance_group_members agm
         JOIN attendance_groups ag ON agm.group_id = ag.id
         WHERE agm.user_id = ? AND ag.status = 1
         LIMIT 1`,
        [userId]
      );
      if (groupRows.length > 0) {
        return res.json(successResponse({
          shift_name: '默认班次',
          start_time: groupRows[0].start_time,
          end_time: groupRows[0].end_time,
          late_tolerance: groupRows[0].late_tolerance,
          early_leave_tolerance: groupRows[0].early_leave_tolerance,
          is_default: true
        }));
      }
      return res.json(successResponse(null));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    logger.error('获取今日排班失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getSchedules, batchSchedule, setRestDay, deleteSchedule, getCalendar, getTodaySchedule };
