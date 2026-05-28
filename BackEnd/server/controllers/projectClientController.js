/**
 * 甲方项目授权控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');

async function getClientProjects(req, res) {
  try {
    const db = getPool();
    const { client_id, project_id } = req.query;

    if (!client_id && !project_id) {
      return res.status(400).json(errorResponse('client_id 和 project_id 至少需要一个', 400));
    }

    const where = [];
    const params = [];
    if (client_id) {
      where.push('pc.client_id = ?');
      params.push(parseInt(client_id));
    }
    if (project_id) {
      where.push('pc.project_id = ?');
      params.push(parseInt(project_id));
    }

    const [rows] = await db.execute(
      `SELECT pc.id, pc.client_id, pc.project_id, pc.created_at,
              p.name AS project_name, p.address, p.status,
              u.name AS client_name, u.username AS client_username, u.phone AS client_phone
       FROM project_clients pc
       JOIN projects p ON pc.project_id = p.id
       JOIN users u ON pc.client_id = u.id
       WHERE ${where.join(' AND ')}
       ORDER BY pc.created_at DESC`,
      params
    );

    res.json(successResponse(rows));
  } catch (err) {
    console.error('获取甲方项目授权失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function bindClientToProject(req, res) {
  try {
    const { client_id, project_id } = req.body;

    if (!client_id || !project_id) {
      return res.status(400).json(errorResponse('client_id 和 project_id 不能为空', 400));
    }

    const db = getPool();
    const [clients] = await db.execute(
      'SELECT id, role FROM users WHERE id = ? AND role = ?',
      [parseInt(client_id), 'client']
    );
    if (clients.length === 0) {
      return res.status(400).json(errorResponse('指定的用户不存在或不是甲方用户', 400));
    }

    const [projects] = await db.execute('SELECT id FROM projects WHERE id = ?', [parseInt(project_id)]);
    if (projects.length === 0) {
      return res.status(400).json(errorResponse('指定的项目不存在', 400));
    }

    try {
      const [result] = await db.execute(
        'INSERT INTO project_clients (client_id, project_id) VALUES (?, ?)',
        [parseInt(client_id), parseInt(project_id)]
      );
      res.json(successResponse({ id: result.insertId }, '授权成功'));
    } catch (e) {
      if (e.code === 'ER_DUP_ENTRY') {
        return res.status(400).json(errorResponse('该甲方用户已绑定此项目', 400));
      }
      throw e;
    }
  } catch (err) {
    console.error('绑定甲方用户到项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function unbindClientFromProject(req, res) {
  try {
    const db = getPool();
    const { id } = req.params;

    const [rows] = await db.execute('SELECT id FROM project_clients WHERE id = ?', [parseInt(id)]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('授权记录不存在', 404));
    }

    await db.execute('DELETE FROM project_clients WHERE id = ?', [parseInt(id)]);
    res.json(successResponse(null, '解绑成功'));
  } catch (err) {
    console.error('解绑甲方项目失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getClientProjects, bindClientToProject, unbindClientFromProject };
