/**
 * 班次管理控制器
 * 支持：早班、晚班、夜班、轮班等多班次
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const logger = require('../utils/logger');

/**
 * 获取班次列表
 * GET /api/shifts
 */
async function getShifts(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, status } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND name LIKE ?';
      params.push(`%${keyword}%`);
    }
    if (status !== undefined && status !== '') {
      where += ' AND status = ?';
      params.push(parseInt(status));
    }

    const [countRows] = await db.execute(`SELECT COUNT(*) as total FROM shifts ${where}`, params);
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT * FROM shifts ${where} ORDER BY sort_order ASC, created_at DESC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({ list: rows, total, page, pageSize }));
  } catch (err) {
    logger.error('获取班次列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单个班次
 * GET /api/shifts/:id
 */
async function getShiftById(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute('SELECT * FROM shifts WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('班次不存在', 404));
    }
    res.json(successResponse(rows[0]));
  } catch (err) {
    logger.error('获取班次详情失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建班次
 * POST /api/shifts
 */
async function createShift(req, res) {
  try {
    const { name, start_time, end_time, late_tolerance, early_leave_tolerance, color, sort_order } = req.body;
    if (!name || !start_time || !end_time) {
      return res.status(400).json(errorResponse('班次名称、上班时间、下班时间不能为空', 400));
    }

    const db = getPool();
    const [result] = await db.execute(
      'INSERT INTO shifts (name, start_time, end_time, late_tolerance, early_leave_tolerance, color, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, start_time, end_time, late_tolerance || 15, early_leave_tolerance || 15, color || '#3B82F6', sort_order || 0]
    );

    res.json(successResponse({ id: result.insertId }, '班次创建成功'));
  } catch (err) {
    logger.error('创建班次失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新班次
 * PUT /api/shifts/:id
 */
async function updateShift(req, res) {
  try {
    const { name, start_time, end_time, late_tolerance, early_leave_tolerance, color, sort_order, status } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (start_time !== undefined) { fields.push('start_time = ?'); params.push(start_time); }
    if (end_time !== undefined) { fields.push('end_time = ?'); params.push(end_time); }
    if (late_tolerance !== undefined) { fields.push('late_tolerance = ?'); params.push(late_tolerance); }
    if (early_leave_tolerance !== undefined) { fields.push('early_leave_tolerance = ?'); params.push(early_leave_tolerance); }
    if (color !== undefined) { fields.push('color = ?'); params.push(color); }
    if (sort_order !== undefined) { fields.push('sort_order = ?'); params.push(sort_order); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE shifts SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '班次更新成功'));
  } catch (err) {
    logger.error('更新班次失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除班次
 * DELETE /api/shifts/:id
 */
async function deleteShift(req, res) {
  try {
    const db = getPool();
    await db.execute('DELETE FROM shifts WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '班次删除成功'));
  } catch (err) {
    logger.error('删除班次失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getShifts, getShiftById, createShift, updateShift, deleteShift };
