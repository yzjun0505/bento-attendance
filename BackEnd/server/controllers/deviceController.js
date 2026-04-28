/**
 * 设备管理控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');

/**
 * 获取设备列表
 * GET /api/devices
 */
async function getDevices(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, status, type, project_id } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND (d.name LIKE ? OR d.device_id LIKE ?)';
      params.push(`%${keyword}%`, `%${keyword}%`);
    }
    if (status !== undefined && status !== '') {
      where += ' AND d.status = ?';
      params.push(parseInt(status));
    }
    if (type) {
      where += ' AND d.type = ?';
      params.push(type);
    }
    if (project_id) {
      where += ' AND d.project_id = ?';
      params.push(parseInt(project_id));
    }

    const [countRows] = await db.query(
      `SELECT COUNT(*) as total FROM devices d ${where}`,
      params
    );

    // 查询分页列表
    const [rows] = await db.query(
      `SELECT d.*, p.name as project_name 
       FROM devices d 
       LEFT JOIN projects p ON d.project_id = p.id 
       ${where} 
       ORDER BY d.created_at DESC 
       LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({
      list: rows,
      total: countRows[0].total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取设备列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建设备
 * POST /api/devices
 */
async function createDevice(req, res) {
  try {
    const { device_id, name, type, project_id, status, latitude, longitude } = req.body;
    if (!device_id || !name) {
      return res.status(400).json(errorResponse('设备ID和名称不能为空', 400));
    }

    const db = getPool();
    
    // 检查冲突
    const [exist] = await db.execute('SELECT id FROM devices WHERE device_id = ?', [device_id]);
    if (exist.length > 0) {
      return res.status(400).json(errorResponse('设备ID已存在', 400));
    }

    const [result] = await db.execute(
      `INSERT INTO devices 
       (device_id, name, type, project_id, status, latitude, longitude) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        device_id, 
        name, 
        type || 'checkpoint', 
        project_id || null, 
        status !== undefined ? status : 1, 
        latitude || null, 
        longitude || null
      ]
    );

    res.json(successResponse({ id: result.insertId }, '设备添加成功'));
  } catch (err) {
    console.error('创建设备失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新设备
 * PUT /api/devices/:id
 */
async function updateDevice(req, res) {
  try {
    const { device_id, name, type, project_id, status, latitude, longitude } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (device_id !== undefined) { fields.push('device_id = ?'); params.push(device_id); }
    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (type !== undefined) { fields.push('type = ?'); params.push(type); }
    if (project_id !== undefined) { fields.push('project_id = ?'); params.push(project_id === '' ? null : project_id); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (latitude !== undefined) { fields.push('latitude = ?'); params.push(latitude === '' ? null : latitude); }
    if (longitude !== undefined) { fields.push('longitude = ?'); params.push(longitude === '' ? null : longitude); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE devices SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '设备更新成功'));
  } catch (err) {
    console.error('更新设备失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除设备
 * DELETE /api/devices/:id
 */
async function deleteDevice(req, res) {
  try {
    const db = getPool();
    await db.execute('DELETE FROM devices WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '设备删除成功'));
  } catch (err) {
    console.error('删除设备失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getDevices, createDevice, updateDevice, deleteDevice };
