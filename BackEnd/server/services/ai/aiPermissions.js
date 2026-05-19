const { getPool } = require('../../models/db');

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

function canManage(actor) {
  return actor.role === 'admin' || actor.role === 'manager';
}

function isAdmin(actor) {
  return actor.role === 'admin';
}

function scopeUserWhere(actor, userAlias = 'u') {
  if (isAdmin(actor)) return { sql: '', params: [] };
  if (actor.role === 'manager' && actor.project_id) {
    return { sql: ` AND ${userAlias}.project_id = ?`, params: [actor.project_id] };
  }
  return { sql: ` AND ${userAlias}.id = ?`, params: [actor.id] };
}

function scopeCheckinWhere(actor, checkinAlias = 'c') {
  if (isAdmin(actor)) return { sql: '', params: [] };
  if (actor.role === 'manager' && actor.project_id) {
    return { sql: ` AND ${checkinAlias}.project_id = ?`, params: [actor.project_id] };
  }
  return { sql: ` AND ${checkinAlias}.user_id = ?`, params: [actor.id] };
}

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
