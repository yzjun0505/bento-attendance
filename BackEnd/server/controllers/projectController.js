/**
 * 项目管理控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');

/**
 * 获取项目列表
 * GET /api/projects
 */
async function getProjects(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, status } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND (name LIKE ? OR address LIKE ?)';
      const kw = `%${keyword}%`;
      params.push(kw, kw);
    }
    if (status !== undefined && status !== '') {
      where += ' AND status = ?';
      params.push(parseInt(status));
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM projects ${where}`,
      params
    );

    const [rows] = await db.query(
      `SELECT * FROM projects ${where} ORDER BY created_at DESC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    // 为每个项目附加人员数量
    for (const project of rows) {
      const [userCount] = await db.execute(
        'SELECT COUNT(*) as count FROM users WHERE project_id = ? AND status = 1',
        [project.id]
      );
      project.user_count = userCount[0].count;
    }

    res.json(successResponse({
      list: rows,
      total: countRows[0].total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取项目列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单个项目
 * GET /api/projects/:id
 */
async function getProjectById(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute('SELECT * FROM projects WHERE id = ?', [req.params.id]);

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('项目不存在', 404));
    }

    // 附加人员列表
    const [users] = await db.execute(
      'SELECT id, username, name, role, phone, avatar FROM users WHERE project_id = ? AND status = 1',
      [req.params.id]
    );

    res.json(successResponse({ ...rows[0], users }));
  } catch (err) {
    console.error('获取项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建项目
 * POST /api/projects
 */
async function createProject(req, res) {
  try {
    const { name, address, latitude, longitude, radius, description } = req.body;
    if (!name) {
      return res.status(400).json(errorResponse('项目名称不能为空', 400));
    }

    const db = getPool();
    const [result] = await db.execute(
      'INSERT INTO projects (name, address, latitude, longitude, radius, description) VALUES (?, ?, ?, ?, ?, ?)',
      [name, address || '', latitude || null, longitude || null, radius || 500, description || '']
    );

    res.json(successResponse({ id: result.insertId }, '项目创建成功'));
  } catch (err) {
    console.error('创建项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新项目
 * PUT /api/projects/:id
 */
async function updateProject(req, res) {
  try {
    const { name, address, latitude, longitude, radius, status, description } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (address !== undefined) { fields.push('address = ?'); params.push(address); }
    if (latitude !== undefined) { fields.push('latitude = ?'); params.push(latitude); }
    if (longitude !== undefined) { fields.push('longitude = ?'); params.push(longitude); }
    if (radius !== undefined) { fields.push('radius = ?'); params.push(radius); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (description !== undefined) { fields.push('description = ?'); params.push(description); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE projects SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '项目更新成功'));
  } catch (err) {
    console.error('更新项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除项目
 * DELETE /api/projects/:id
 */
async function deleteProject(req, res) {
  try {
    const db = getPool();

    // 检查是否有关联用户
    const [users] = await db.execute(
      'SELECT COUNT(*) as count FROM users WHERE project_id = ? AND status = 1',
      [req.params.id]
    );
    if (users[0].count > 0) {
      return res.status(400).json(errorResponse('该项目下还有在职人员，无法删除', 400));
    }

    await db.execute('DELETE FROM projects WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '项目删除成功'));
  } catch (err) {
    console.error('删除项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取所有项目（下拉框用，不分页）
 * GET /api/projects/all
 */
async function getAllProjects(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute('SELECT id, name, latitude, longitude, radius FROM projects WHERE status = 1 ORDER BY name');
    res.json(successResponse(rows));
  } catch (err) {
    console.error('获取项目列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 查询附近项目
 * GET /api/projects/nearby?latitude=xxx&longitude=xxx&radius=2000
 * 返回指定半径内的所有项目，按距离排序
 */
async function getNearbyProjects(req, res) {
  try {
    const { latitude, longitude, radius } = req.query;
    if (!latitude || !longitude) {
      return res.status(400).json(errorResponse('缺少经纬度参数', 400));
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    const searchRadius = parseInt(radius) || 2000; // 默认搜索2km

    const db = getPool();
    const [rows] = await db.execute(
      'SELECT id, name, address, latitude, longitude, radius, status FROM projects WHERE status = 1 AND latitude IS NOT NULL AND longitude IS NOT NULL'
    );

    // 计算距离并筛选
    const nearby = [];
    for (const project of rows) {
      const distance = calculateDistance(lat, lng, project.latitude, project.longitude);
      if (distance <= searchRadius) {
        nearby.push({
          ...project,
          distance: Math.round(distance),
          isInside: distance <= (project.radius || 500)
        });
      }
    }

    // 按距离排序
    nearby.sort((a, b) => a.distance - b.distance);

    res.json(successResponse(nearby));
  } catch (err) {
    console.error('查询附近项目失败:', err);
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

module.exports = { getProjects, getProjectById, createProject, updateProject, deleteProject, getAllProjects, getNearbyProjects };
