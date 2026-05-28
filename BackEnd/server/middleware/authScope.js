/**
 * 数据访问权限中间件
 * 根据用户角色计算可访问的用户ID范围
 */
const { getPool } = require('../models/db');

/**
 * 获取项目经理的授权项目ID列表
 * @param {number} userId - 项目经理的用户ID
 * @returns {Promise<number[]>} 授权项目ID数组
 */
async function getManagerProjectIds(userId) {
  const db = getPool();
  const [rows] = await db.execute(
    'SELECT project_id FROM project_managers WHERE manager_id = ?',
    [userId]
  );
  return rows.map(r => r.project_id);
}

async function getClientProjectIds(userId) {
  const db = getPool();
  const [rows] = await db.execute(
    'SELECT project_id FROM project_clients WHERE client_id = ?',
    [userId]
  );
  return rows.map(r => r.project_id);
}

/**
 * 根据当前用户角色返回可访问的项目ID范围
 *   worker  → 自己所属项目
 *   client  → 授权查看的项目
 *   manager → 授权管理的项目
 *   admin   → 所有项目
 * @param {object} req - Express 请求对象 (需包含 req.user)
 * @returns {Promise<number[]>} 可访问的项目ID数组
 */
async function getAccessibleProjectIds(req) {
  const db = getPool();
  const { id: userId, role } = req.user;

  if (role === 'admin') {
    const [rows] = await db.execute('SELECT id FROM projects');
    return rows.map(r => r.id);
  }

  if (role === 'manager') {
    return getManagerProjectIds(userId);
  }

  if (role === 'client') {
    return getClientProjectIds(userId);
  }

  const [rows] = await db.execute(
    'SELECT project_id FROM users WHERE id = ?',
    [userId]
  );
  return rows.length && rows[0].project_id ? [rows[0].project_id] : [];
}

async function canAccessProject(req, projectId) {
  const projectIds = await getAccessibleProjectIds(req);
  return projectIds.includes(Number(projectId));
}

/**
 * 根据当前用户角色返回可访问的用户ID范围
 *   worker/client → 仅自己 [userId]
 *   manager → 自己 + 所有授权项目下 role='worker' 的用户
 *   admin   → 所有 role IN ('manager', 'worker') 的用户
 * @param {object} req - Express 请求对象 (需包含 req.user)
 * @returns {Promise<number[]>} 可访问的用户ID数组
 */
async function getAccessibleUserIds(req) {
  const db = getPool();
  const { id: userId, role } = req.user;

  if (role === 'worker' || role === 'client') {
    return [userId];
  }

  if (role === 'admin') {
    const [rows] = await db.execute(
      "SELECT id FROM users WHERE role IN ('manager', 'worker')"
    );
    return rows.map(r => r.id);
  }

  if (role === 'manager') {
    const projectIds = await getManagerProjectIds(userId);
    if (projectIds.length === 0) {
      return [userId];
    }

    const placeholders = projectIds.map(() => '?').join(',');
    const [rows] = await db.execute(
      `SELECT id FROM users WHERE (id = ? OR (role = 'worker' AND project_id IN (${placeholders})))`,
      [userId, ...projectIds]
    );
    return rows.map(r => r.id);
  }

  return [userId];
}

module.exports = {
  getManagerProjectIds,
  getClientProjectIds,
  getAccessibleProjectIds,
  canAccessProject,
  getAccessibleUserIds
};
