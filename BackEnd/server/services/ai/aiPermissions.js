/**
 * AI 操作权限控制模块
 *
 * 职责：定义 AI 助手能"看到"和"操作"的数据范围。
 *
 * 三级权限模型：
 *   admin   → 全量数据，所有操作
 *   manager → 仅自己负责的项目（project_id 过滤）
 *   worker  → 仅自己的数据
 *
 * 核心方法是三个 scopeXxxWhere()，生成可拼接的 SQL WHERE 子句。
 * AI 的每个数据库查询都通过它们来限制数据可见范围。
 */

const { getPool } = require('../../models/db');

/**
 * 加载当前用户完整信息（含角色、项目），权限判断的基础。
 * @param {Object} user — { id, username, name?, role?, project_id? }
 * @returns {Object} actor — { id, username, name, role, project_id }
 */
async function loadActor(user) {
  const db = getPool();
  const [rows] = await db.execute(
    `SELECT id, username, name, role, project_id, phone, email
     FROM users
     WHERE id = ? AND status = 1
     LIMIT 1`,
    [Number(user.id)]
  );
  return rows[0] || {
    id: Number(user.id),
    username: user.username,
    name: user.name || user.username || '',
    role: user.role || 'worker',
    project_id: user.project_id || null,
  };
}

/**
 * 是否有管理权限（admin 或 manager）
 */
function canManage(actor) {
  return actor.role === 'admin' || actor.role === 'manager';
}

/**
 * 是否为系统管理员
 */
function isAdmin(actor) {
  return actor.role === 'admin';
}

/**
 * 生成用户维度的数据过滤 SQL
 *
 * 规则：
 *   admin   → 不限制（空 SQL）
 *   manager → 限定同 project_id
 *   worker  → 只能看自己
 *
 * @param {Object} actor — 当前用户
 * @param {string} userAlias — users 表别名（默认 'u'）
 * @returns {{ sql: string, params: Array }} — 可拼接到 WHERE 子句
 *
 * 示例：scopeUserWhere(actor, 'u')
 *   → admin 返回 { sql: '', params: [] }
 *   → manager 返回 { sql: ' AND u.project_id = ?', params: [5] }
 *   → worker 返回 { sql: ' AND u.id = ?', params: [3] }
 */
function scopeUserWhere(actor, userAlias = 'u') {
  if (isAdmin(actor)) return { sql: '', params: [] };
  if (actor.role === 'manager' && actor.project_id) {
    return { sql: ` AND ${userAlias}.project_id = ?`, params: [actor.project_id] };
  }
  return { sql: ` AND ${userAlias}.id = ?`, params: [actor.id] };
}

/**
 * 生成打卡/考勤维度的数据过滤 SQL
 *
 * 规则同 scopeUserWhere，但作用于 checkins 表。
 * manager 限定同项目的打卡记录，worker 只看到自己的。
 *
 * @param {Object} actor
 * @param {string} checkinAlias — checkins 表别名（默认 'c'）
 * @returns {{ sql: string, params: Array }}
 */
function scopeCheckinWhere(actor, checkinAlias = 'c') {
  if (isAdmin(actor)) return { sql: '', params: [] };
  if (actor.role === 'manager' && actor.project_id) {
    return { sql: ` AND ${checkinAlias}.project_id = ?`, params: [actor.project_id] };
  }
  return { sql: ` AND ${checkinAlias}.user_id = ?`, params: [actor.id] };
}

/**
 * 生成项目维度的数据过滤 SQL
 *
 * 特殊：worker 看不到任何项目（1=0 恒假）。
 * 因为 worker 不应看到项目级统计数据，只能看自己的打卡记录。
 *
 * @param {Object} actor
 * @param {string} projectAlias — projects 表别名（默认 'p'）
 * @returns {{ sql: string, params: Array }}
 */
function scopeProjectWhere(actor, projectAlias = 'p') {
  if (isAdmin(actor)) return { sql: '', params: [] };
  if (actor.role === 'manager' && actor.project_id) {
    return { sql: ` AND ${projectAlias}.id = ?`, params: [actor.project_id] };
  }
  return { sql: ' AND 1 = 0', params: [] };
}

module.exports = {
  loadActor,
  canManage,
  isAdmin,
  scopeUserWhere,
  scopeCheckinWhere,
  scopeProjectWhere,
};
