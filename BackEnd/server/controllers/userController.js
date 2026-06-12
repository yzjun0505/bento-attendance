/**
 * 用户管理控制器
 */
const bcrypt = require('bcryptjs');
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const tencentIMService = require('../services/tencentImService');

function getPublicBaseUrl(req) {
  const configured = process.env.PUBLIC_BASE_URL || process.env.APP_PUBLIC_URL || '';
  if (configured) return configured.replace(/\/+$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

function toPublicUrl(req, value) {
  if (!value) return '';
  const raw = String(value).trim();
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw)) return raw;
  const path = raw.startsWith('/') ? raw : `/${raw}`;
  return `${getPublicBaseUrl(req)}${path}`;
}

function normalizePhone(phone) {
  return String(phone || '').trim();
}

function isValidPhone(phone) {
  return /^\d{11}$/.test(normalizePhone(phone));
}

const VALID_USER_ROLES = new Set(['admin', 'manager', 'worker', 'client']);
const MANAGER_MANAGEABLE_ROLES = new Set(['worker', 'client']);

function validateUserRole(role) {
  if (role !== undefined && !VALID_USER_ROLES.has(role)) {
    return { ok: false, status: 400, message: '无效的用户角色' };
  }
  return { ok: true };
}

function canManagerManageRole(role) {
  return MANAGER_MANAGEABLE_ROLES.has(role);
}

function ensureCreatePermission(actor, role) {
  if (actor.role === 'admin') {
    return { ok: true };
  }
  if (actor.role === 'manager' && canManagerManageRole(role)) {
    return { ok: true };
  }
  return { ok: false, status: 403, message: '项目经理只能创建工人或甲方用户' };
}

async function ensureTargetManagePermission(db, actor, targetUserId, nextRole) {
  const [rows] = await db.execute('SELECT role FROM users WHERE id = ?', [targetUserId]);
  if (rows.length === 0) {
    return { ok: false, status: 404, message: '用户不存在' };
  }

  const currentRole = rows[0].role;
  if (actor.role === 'admin') {
    return { ok: true, currentRole };
  }

  if (actor.role !== 'manager') {
    return { ok: false, status: 403, message: '无权限操作该用户' };
  }

  if (!canManagerManageRole(currentRole)) {
    return { ok: false, status: 403, message: '项目经理不能管理管理员或项目经理账号' };
  }

  if (nextRole !== undefined && !canManagerManageRole(nextRole)) {
    return { ok: false, status: 403, message: '项目经理不能把用户设置为管理员或项目经理' };
  }

  return { ok: true, currentRole };
}

async function verifySecondaryPassword(db, req, password) {
  if (!password) {
    return { ok: false, status: 400, message: '请输入二级密码' };
  }

  const [rows] = await db.execute(
    'SELECT password FROM users WHERE id = ?',
    [req.user.id]
  );

  if (rows.length === 0) {
    return { ok: false, status: 404, message: '当前登录用户不存在' };
  }

  const isMatch = await bcrypt.compare(password, rows[0].password);
  if (!isMatch) {
    return { ok: false, status: 400, message: '二级密码错误' };
  }

  return { ok: true };
}

async function ensureLastActiveAdminSafe(db, userId, nextRole, nextStatus) {
  const [rows] = await db.execute('SELECT role, status FROM users WHERE id = ?', [userId]);
  if (rows.length === 0) {
    return { ok: false, status: 404, message: '用户不存在' };
  }

  const current = rows[0];
  const roleAfterUpdate = nextRole !== undefined ? nextRole : current.role;
  const statusAfterUpdate = nextStatus !== undefined ? Number(nextStatus) : current.status;

  if (current.role !== 'admin' || (roleAfterUpdate === 'admin' && statusAfterUpdate === 1)) {
    return { ok: true };
  }

  const [adminRows] = await db.execute(
    'SELECT COUNT(*) as count FROM users WHERE role = ? AND status = 1 AND id <> ?',
    ['admin', userId]
  );

  if (adminRows[0].count === 0) {
    return { ok: false, status: 400, message: '至少保留一个在职管理员账号' };
  }

  return { ok: true };
}

async function ensureAdminDeletionSafe(db, actor, targetUserId) {
  if (actor.role !== 'admin') {
    return { ok: false, status: 403, message: '只有管理员可以删除管理员账号' };
  }
  if (Number(actor.id) === Number(targetUserId)) {
    return { ok: false, status: 400, message: '不能删除当前登录的管理员账号' };
  }

  const [adminRows] = await db.execute(
    'SELECT COUNT(*) as count FROM users WHERE role = ? AND status = 1 AND id <> ?',
    ['admin', targetUserId]
  );

  if (adminRows[0].count === 0) {
    return { ok: false, status: 400, message: '至少保留一个在职管理员账号' };
  }

  return { ok: true };
}

/**
 * 获取用户列表
 * GET /api/users
 */
async function getUsers(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, role, status, project_id } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND (u.name LIKE ? OR u.username LIKE ? OR u.phone LIKE ?)';
      const kw = `%${keyword}%`;
      params.push(kw, kw, kw);
    }
    if (role) {
      where += ' AND u.role = ?';
      params.push(role);
    }
    if (req.user.role === 'manager') {
      where += " AND u.role IN ('worker', 'client')";
    }
    if (status !== undefined && status !== '') {
      where += ' AND u.status = ?';
      params.push(parseInt(status));
    }
    if (project_id) {
      where += ' AND u.project_id = ?';
      params.push(parseInt(project_id));
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM users u ${where}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT u.id, u.username, u.name, u.role, u.phone, u.email, u.avatar, u.status, u.project_id, u.created_at, p.name as project_name 
       FROM users u LEFT JOIN projects p ON u.project_id = p.id ${where}
       ORDER BY u.created_at DESC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({
      list: rows,
      total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取用户列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单个用户
 * GET /api/users/:id
 */
async function getUserById(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.name, u.role, u.phone, u.email, u.avatar, u.status, u.project_id, u.created_at, p.name as project_name 
       FROM users u LEFT JOIN projects p ON u.project_id = p.id WHERE u.id = ?`,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }
    if (req.user.role === 'manager' && !canManagerManageRole(rows[0].role)) {
      return res.status(403).json(errorResponse('项目经理不能查看管理员或项目经理账号', 403));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    console.error('获取用户失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建用户
 * POST /api/users
 */
async function createUser(req, res) {
  try {
    const { username, password, name, role, phone, project_id, secondaryPassword } = req.body;
    const targetRole = role || 'worker';
    if (!username || !password) {
      return res.status(400).json(errorResponse('用户名和密码不能为空', 400));
    }
    const roleCheck = validateUserRole(targetRole);
    if (!roleCheck.ok) {
      return res.status(roleCheck.status).json(errorResponse(roleCheck.message, roleCheck.status));
    }

    const normalizedPhone = normalizePhone(phone);
    if (!isValidPhone(normalizedPhone)) {
      return res.status(400).json(errorResponse('手机号必须为11位数字', 400));
    }

    const db = getPool();
    const permissionCheck = ensureCreatePermission(req.user, targetRole);
    if (!permissionCheck.ok) {
      return res.status(permissionCheck.status).json(errorResponse(permissionCheck.message, permissionCheck.status));
    }

    const secondaryCheck = await verifySecondaryPassword(db, req, secondaryPassword);
    if (!secondaryCheck.ok) {
      return res.status(secondaryCheck.status).json(errorResponse(secondaryCheck.message, secondaryCheck.status));
    }

    const [existing] = await db.execute('SELECT id FROM users WHERE username = ?', [username]);
    if (existing.length > 0) {
      return res.status(400).json(errorResponse('用户名已存在', 400));
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await db.execute(
      'INSERT INTO users (username, password, name, role, phone, project_id) VALUES (?, ?, ?, ?, ?, ?)',
      [username, hashedPassword, name || '', targetRole, normalizedPhone, project_id || null]
    );

    // 异步同步到腾讯云 IM
    (async () => {
      try {
        const userId = result.insertId;
        console.log(`创建用户后同步到腾讯云 IM [用户ID: ${userId}]`);
        
        const regResult = await tencentIMService.registerUser({
          userID: userId,
          nickname: name || username,
          faceURL: '',
          role: role || 'worker',
        });
        
        if (regResult.success) {
          console.log(`腾讯云 IM 同步成功 [${userId}]:`, regResult.existed ? '用户已存在' : '新用户注册');
        } else {
          console.warn(`腾讯云 IM 同步失败 [${userId}]:`, regResult.message);
        }
      } catch (err) {
        console.warn(`腾讯云 IM 同步异常 [${result.insertId}]:`, err.message);
      }
    })();

    res.json(successResponse({ id: result.insertId }, '用户创建成功'));
  } catch (err) {
    console.error('创建用户失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新用户
 * PUT /api/users/:id
 */
async function updateUser(req, res) {
  try {
    const { name, role, phone, email, project_id, status, avatar } = req.body;
    const db = getPool();

    const roleCheck = validateUserRole(role);
    if (!roleCheck.ok) {
      return res.status(roleCheck.status).json(errorResponse(roleCheck.message, roleCheck.status));
    }

    const permissionCheck = await ensureTargetManagePermission(db, req.user, req.params.id, role);
    if (!permissionCheck.ok) {
      return res.status(permissionCheck.status).json(errorResponse(permissionCheck.message, permissionCheck.status));
    }

    const adminSafety = await ensureLastActiveAdminSafe(db, req.params.id, role, status);
    if (!adminSafety.ok) {
      return res.status(adminSafety.status).json(errorResponse(adminSafety.message, adminSafety.status));
    }

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (role !== undefined) { fields.push('role = ?'); params.push(role); }
    if (phone !== undefined) {
      const normalizedPhone = normalizePhone(phone);
      if (!isValidPhone(normalizedPhone)) {
        return res.status(400).json(errorResponse('手机号必须为11位数字', 400));
      }
      fields.push('phone = ?');
      params.push(normalizedPhone);
    }
    if (email !== undefined) { fields.push('email = ?'); params.push(email); }
    if (project_id !== undefined) { fields.push('project_id = ?'); params.push(project_id || null); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (avatar !== undefined) { fields.push('avatar = ?'); params.push(toPublicUrl(req, avatar)); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);

    // 异步同步到腾讯云 IM
    (async () => {
      try {
        const userId = req.params.id;
        console.log(`更新用户后同步到腾讯云 IM [用户ID: ${userId}]`);
        
        const db = getPool();
        const [userRows] = await db.execute(
          'SELECT name, avatar, role FROM users WHERE id = ?',
          [userId]
        );
        
        if (userRows.length > 0) {
          const user = userRows[0];
          const updateResult = await tencentIMService.updateUserInfo({
            userID: userId,
            nickname: user.name,
            faceURL: user.avatar || '',
            role: user.role,
          });
          
          if (updateResult.success) {
            console.log(`腾讯云 IM 用户信息更新成功 [${userId}]`);
          } else {
            console.warn(`腾讯云 IM 用户信息更新失败 [${userId}]:`, updateResult.message);
          }
        }
      } catch (err) {
        console.warn(`腾讯云 IM 同步异常 [${req.params.id}]:`, err.message);
      }
    })();

    res.json(successResponse(null, '用户更新成功'));
  } catch (err) {
    console.error('更新用户失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除用户
 * DELETE /api/users/:id
 */
async function deleteUser(req, res) {
  try {
    const { secondaryPassword } = req.body || {};
    const db = getPool();
    const [rows] = await db.execute('SELECT role, status FROM users WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }
    const permissionCheck = await ensureTargetManagePermission(db, req.user, req.params.id);
    if (!permissionCheck.ok) {
      return res.status(permissionCheck.status).json(errorResponse(permissionCheck.message, permissionCheck.status));
    }
    if (rows[0].role === 'admin') {
      const adminDeletionCheck = await ensureAdminDeletionSafe(db, req.user, req.params.id);
      if (!adminDeletionCheck.ok) {
        return res.status(adminDeletionCheck.status).json(errorResponse(adminDeletionCheck.message, adminDeletionCheck.status));
      }
    }
    const secondaryCheck = await verifySecondaryPassword(db, req, secondaryPassword);
    if (!secondaryCheck.ok) {
      return res.status(secondaryCheck.status).json(errorResponse(secondaryCheck.message, secondaryCheck.status));
    }

    await db.execute('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '用户删除成功'));
  } catch (err) {
    console.error('删除用户失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 重置用户密码
 * PUT /api/users/:id/reset-password
 */
async function resetPassword(req, res) {
  try {
    const { password, secondaryPassword } = req.body;
    if (!password) {
      return res.status(400).json(errorResponse('新密码不能为空', 400));
    }

    const db = getPool();
    const [rows] = await db.execute('SELECT id FROM users WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }
    const permissionCheck = await ensureTargetManagePermission(db, req.user, req.params.id);
    if (!permissionCheck.ok) {
      return res.status(permissionCheck.status).json(errorResponse(permissionCheck.message, permissionCheck.status));
    }
    const secondaryCheck = await verifySecondaryPassword(db, req, secondaryPassword);
    if (!secondaryCheck.ok) {
      return res.status(secondaryCheck.status).json(errorResponse(secondaryCheck.message, secondaryCheck.status));
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    await db.execute('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, req.params.id]);

    res.json(successResponse(null, '密码重置成功'));
  } catch (err) {
    console.error('重置密码失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 修改当前用户密码
 * PUT /api/users/me/password
 */
async function changePassword(req, res) {
  try {
    const { oldPassword, newPassword } = req.body;
    
    if (!oldPassword || !newPassword) {
      return res.status(400).json(errorResponse('旧密码和新密码不能为空', 400));
    }

    if (newPassword.length < 6) {
      return res.status(400).json(errorResponse('新密码长度不能少于6位', 400));
    }

    const db = getPool();
    const userId = req.user.id;

    const [rows] = await db.execute(
      'SELECT password FROM users WHERE id = ?',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }

    const isMatch = await bcrypt.compare(oldPassword, rows[0].password);
    if (!isMatch) {
      return res.status(400).json(errorResponse('旧密码错误', 400));
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await db.execute('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, userId]);

    res.json(successResponse(null, '密码修改成功'));
  } catch (err) {
    console.error('修改密码失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取当前登录用户信息
 * GET /api/users/me
 */
async function getCurrentUser(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.name, u.role, u.phone, u.email, u.avatar, u.status, u.project_id, u.created_at, p.name as project_name 
       FROM users u LEFT JOIN projects p ON u.project_id = p.id WHERE u.id = ?`,
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    console.error('获取当前用户信息失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新当前用户信息
 * PUT /api/users/me
 */
async function updateCurrentUser(req, res) {
  try {
    const { name, phone, email, avatar } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (phone !== undefined) { fields.push('phone = ?'); params.push(phone); }
    if (email !== undefined) { fields.push('email = ?'); params.push(email); }
    if (avatar !== undefined) { fields.push('avatar = ?'); params.push(toPublicUrl(req, avatar)); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.user.id);
    await db.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);

    // 异步同步到腾讯云 IM
    (async () => {
      try {
        const userId = req.user.id;
        console.log(`更新个人信息后同步到腾讯云 IM [用户ID: ${userId}]`);
        
        const db = getPool();
        const [userRows] = await db.execute(
          'SELECT name, avatar, role FROM users WHERE id = ?',
          [userId]
        );
        
        if (userRows.length > 0) {
          const user = userRows[0];
          const updateResult = await tencentIMService.updateUserInfo({
            userID: userId,
            nickname: user.name,
            faceURL: user.avatar || '',
            role: user.role,
          });
          
          if (updateResult.success) {
            console.log(`腾讯云 IM 个人信息更新成功 [${userId}]`);
          } else {
            console.warn(`腾讯云 IM 个人信息更新失败 [${userId}]:`, updateResult.message);
          }
        }
      } catch (err) {
        console.warn(`腾讯云 IM 同步异常 [${req.user.id}]:`, err.message);
      }
    })();

    const [updatedRows] = await db.execute(
      `SELECT u.id, u.username, u.name, u.role, u.phone, u.email, u.avatar, u.status, u.project_id, u.created_at, p.name as project_name 
       FROM users u LEFT JOIN projects p ON u.project_id = p.id WHERE u.id = ?`,
      [req.user.id]
    );

    res.json(successResponse(updatedRows[0] || null, '个人信息更新成功'));
  } catch (err) {
    console.error('更新当前用户信息失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 查找用户（用于添加好友）
 * GET /api/users/lookup?q=xxx
 */
async function lookupUser(req, res) {
  try {
    const q = String(req.query.q || '').trim();
    if (!q) {
      return res.status(400).json(errorResponse('请输入用户ID或手机号', 400));
    }

    const db = getPool();
    const isAllDigits = /^\d+$/.test(q);
    const isPhone = isAllDigits && q.length >= 11;

    let rows = [];
    if (isPhone) {
      const [r] = await db.execute(
        `SELECT id, username, name, role, phone, email, avatar, project_id
         FROM users WHERE phone = ? LIMIT 1`,
        [q]
      );
      rows = r;
    } else if (isAllDigits) {
      const [r] = await db.execute(
        `SELECT id, username, name, role, phone, email, avatar, project_id
         FROM users WHERE id = ? LIMIT 1`,
        [Number(q)]
      );
      rows = r;
    } else {
      const [r] = await db.execute(
        `SELECT id, username, name, role, phone, email, avatar, project_id
         FROM users WHERE username = ? LIMIT 1`,
        [q]
      );
      rows = r;
    }

    if (!rows || rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    console.error('查找用户失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getUsers, getUserById, createUser, updateUser, deleteUser, resetPassword, changePassword, getCurrentUser, updateCurrentUser, lookupUser };
