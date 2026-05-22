/**
 * 项目授权控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');

/**
 * 获取项目授权列表
 * GET /api/project-managers?manager_id=xxx
 * GET /api/project-managers?project_id=xxx
 */
async function getManagerProjects(req, res) {
  try {
    const db = getPool();
    const { manager_id, project_id } = req.query;

    if (!manager_id && !project_id) {
      return res.status(400).json(errorResponse('manager_id 和 project_id 至少需要一个', 400));
    }

    const where = [];
    const params = [];
    if (manager_id) {
      where.push('pm.manager_id = ?');
      params.push(parseInt(manager_id));
    }
    if (project_id) {
      where.push('pm.project_id = ?');
      params.push(parseInt(project_id));
    }

    const [rows] = await db.execute(
      `SELECT pm.id, pm.manager_id, pm.project_id, pm.created_at,
              p.name AS project_name, p.address, p.status,
              u.name AS manager_name, u.username AS manager_username, u.phone AS manager_phone
       FROM project_managers pm
       JOIN projects p ON pm.project_id = p.id
       JOIN users u ON pm.manager_id = u.id
       WHERE ${where.join(' AND ')}
       ORDER BY pm.created_at DESC`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    console.error('获取项目经理授权项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 绑定项目经理到项目
 * POST /api/project-managers
 * Body: { manager_id, project_id }
 */
async function bindManagerToProject(req, res) {
  try {
    const { manager_id, project_id } = req.body;

    if (!manager_id || !project_id) {
      return res.status(400).json(errorResponse('manager_id 和 project_id 不能为空', 400));
    }

    const db = getPool();

    const [managers] = await db.execute(
      'SELECT id, role FROM users WHERE id = ? AND role = ?',
      [parseInt(manager_id), 'manager']
    );
    if (managers.length === 0) {
      return res.status(400).json(errorResponse('指定的用户不存在或不是项目经理', 400));
    }

    const [projects] = await db.execute(
      'SELECT id FROM projects WHERE id = ?',
      [parseInt(project_id)]
    );
    if (projects.length === 0) {
      return res.status(400).json(errorResponse('指定的项目不存在', 400));
    }

    try {
      const [result] = await db.execute(
        'INSERT INTO project_managers (manager_id, project_id) VALUES (?, ?)',
        [parseInt(manager_id), parseInt(project_id)]
      );
      res.json(successResponse({ id: result.insertId }, '授权成功'));
    } catch (e) {
      if (e.code === 'ER_DUP_ENTRY') {
        return res.status(400).json(errorResponse('该项目经理已绑定此项目', 400));
      }
      throw e;
    }
  } catch (err) {
    console.error('绑定项目经理到项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 解绑项目经理和项目
 * DELETE /api/project-managers/:id
 */
async function unbindManagerFromProject(req, res) {
  try {
    const db = getPool();
    const { id } = req.params;

    const [rows] = await db.execute(
      'SELECT id FROM project_managers WHERE id = ?',
      [parseInt(id)]
    );
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('授权记录不存在', 404));
    }

    await db.execute('DELETE FROM project_managers WHERE id = ?', [parseInt(id)]);
    res.json(successResponse(null, '解绑成功'));
  } catch (err) {
    console.error('解绑项目经理项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getManagerProjects, bindManagerToProject, unbindManagerFromProject };
