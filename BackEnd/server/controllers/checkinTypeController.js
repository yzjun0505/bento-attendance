/**
 * 打卡类型控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');

/**
 * 获取所有启用的打卡类型
 * GET /api/checkin-types
 */
async function getCheckinTypes(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      'SELECT * FROM checkin_types WHERE status = 1 ORDER BY sort_order ASC, id ASC'
    );
    res.json(successResponse(rows));
  } catch (err) {
    console.error('获取打卡类型失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取所有打卡类型（管理端，含停用）
 * GET /api/checkin-types/all
 */
async function getAllCheckinTypes(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, category, status } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND (name LIKE ? OR code LIKE ?)';
      const kw = `%${keyword}%`;
      params.push(kw, kw);
    }
    if (category) {
      where += ' AND category = ?';
      params.push(category);
    }
    if (status !== undefined && status !== '') {
      where += ' AND status = ?';
      params.push(parseInt(status));
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM checkin_types ${where}`,
      params
    );

    const [rows] = await db.query(
      `SELECT * FROM checkin_types ${where} ORDER BY sort_order ASC, id ASC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({
      list: rows,
      total: countRows[0].total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取打卡类型列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建打卡类型
 * POST /api/checkin-types
 */
async function createCheckinType(req, res) {
  try {
    const { code, name, icon, color, category, count_as_attendance, sort_order } = req.body;
    if (!code || !name) {
      return res.status(400).json(errorResponse('类型编码和名称不能为空', 400));
    }

    const db = getPool();
    try {
      const [result] = await db.execute(
        'INSERT INTO checkin_types (code, name, icon, color, category, count_as_attendance, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [code, name, icon || '', color || '#3B82F6', category || 'business', count_as_attendance || 0, sort_order || 0]
      );
      res.json(successResponse({ id: result.insertId }, '打卡类型创建成功'));
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') {
        return res.status(400).json(errorResponse('类型编码已存在', 400));
      }
      throw err;
    }
  } catch (err) {
    console.error('创建打卡类型失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新打卡类型
 * PUT /api/checkin-types/:id
 */
async function updateCheckinType(req, res) {
  try {
    const { name, icon, color, category, count_as_attendance, sort_order, status } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (icon !== undefined) { fields.push('icon = ?'); params.push(icon); }
    if (color !== undefined) { fields.push('color = ?'); params.push(color); }
    if (category !== undefined) { fields.push('category = ?'); params.push(category); }
    if (count_as_attendance !== undefined) { fields.push('count_as_attendance = ?'); params.push(count_as_attendance); }
    if (sort_order !== undefined) { fields.push('sort_order = ?'); params.push(sort_order); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE checkin_types SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '打卡类型更新成功'));
  } catch (err) {
    console.error('更新打卡类型失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除打卡类型
 * DELETE /api/checkin-types/:id
 */
async function deleteCheckinType(req, res) {
  try {
    const db = getPool();

    // 检查是否有打卡记录使用此类型
    const typeRow = await db.execute('SELECT code FROM checkin_types WHERE id = ?', [req.params.id]);
    if (typeRow[0].length === 0) {
      return res.status(404).json(errorResponse('打卡类型不存在', 404));
    }

    const typeCode = typeRow[0][0].code;
    const [usageCount] = await db.execute(
      'SELECT COUNT(*) as count FROM checkins WHERE type = ?',
      [typeCode]
    );

    if (usageCount[0].count > 0) {
      // 有记录使用，只停用不删除
      await db.execute('UPDATE checkin_types SET status = 0 WHERE id = ?', [req.params.id]);
      return res.json(successResponse(null, '该类型已被打卡记录引用，已停用而非删除'));
    }

    await db.execute('DELETE FROM checkin_types WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '打卡类型删除成功'));
  } catch (err) {
    console.error('删除打卡类型失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = {
  getCheckinTypes,
  getAllCheckinTypes,
  createCheckinType,
  updateCheckinType,
  deleteCheckinType
};
