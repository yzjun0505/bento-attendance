/**
 * 节假日管理控制器
 * 支持法定节假日和调休设置
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 获取节假日列表
 * GET /api/holidays?year=2024
 */
async function getHolidays(req, res) {
  try {
    const db = getPool();
    const { year } = req.query;

    let where = '';
    const params = [];

    if (year) {
      where = 'WHERE year = ?';
      params.push(parseInt(year));
    }

    const [rows] = await db.execute(
      `SELECT * FROM holidays ${where} ORDER BY date ASC`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    logger.error('获取节假日列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建节假日
 * POST /api/holidays
 */
async function createHoliday(req, res) {
  try {
    const { name, date, type } = req.body;
    if (!name || !date) {
      return res.status(400).json(errorResponse('名称和日期不能为空', 400));
    }

    const db = getPool();
    const year = new Date(date).getFullYear();

    const [result] = await db.execute(
      'INSERT INTO holidays (name, date, type, year) VALUES (?, ?, ?, ?)',
      [name, date, type || 'holiday', year]
    );

    res.json(successResponse({ id: result.insertId }, '节假日创建成功'));
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json(errorResponse('该日期已存在节假日设置', 400));
    }
    logger.error('创建节假日失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 批量创建节假日
 * POST /api/holidays/batch
 */
async function batchCreateHolidays(req, res) {
  try {
    const { holidays } = req.body;
    if (!Array.isArray(holidays) || holidays.length === 0) {
      return res.status(400).json(errorResponse('节假日数据不能为空', 400));
    }

    const db = getPool();
    let inserted = 0;
    let skipped = 0;

    for (const h of holidays) {
      const year = new Date(h.date).getFullYear();
      try {
        await db.execute(
          'INSERT INTO holidays (name, date, type, year) VALUES (?, ?, ?, ?)',
          [h.name, h.date, h.type || 'holiday', year]
        );
        inserted++;
      } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
          skipped++;
        } else {
          throw err;
        }
      }
    }

    res.json(successResponse({ inserted, skipped }, `成功创建 ${inserted} 条，跳过 ${skipped} 条`));
  } catch (err) {
    logger.error('批量创建节假日失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新节假日
 * PUT /api/holidays/:id
 */
async function updateHoliday(req, res) {
  try {
    const { name, type } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (type !== undefined) { fields.push('type = ?'); params.push(type); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE holidays SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '节假日更新成功'));
  } catch (err) {
    logger.error('更新节假日失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除节假日
 * DELETE /api/holidays/:id
 */
async function deleteHoliday(req, res) {
  try {
    const db = getPool();
    await db.execute('DELETE FROM holidays WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '节假日删除成功'));
  } catch (err) {
    logger.error('删除节假日失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 检查某天是否是节假日/调休
 * GET /api/holidays/check?date=2024-01-01
 */
async function checkDate(req, res) {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json(errorResponse('日期不能为空', 400));
    }

    const db = getPool();
    const [rows] = await db.execute(
      'SELECT * FROM holidays WHERE date = ?',
      [date]
    );

    if (rows.length > 0) {
      res.json(successResponse({
        is_holiday: rows[0].type === 'holiday',
        is_workday: rows[0].type === 'workday',
        info: rows[0]
      }));
    } else {
      // 判断是否是周末
      const dayOfWeek = new Date(date).getDay();
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
      res.json(successResponse({
        is_holiday: isWeekend,
        is_workday: !isWeekend,
        info: null
      }));
    }
  } catch (err) {
    logger.error('检查日期失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getHolidays, createHoliday, batchCreateHolidays, updateHoliday, deleteHoliday, checkDate };
