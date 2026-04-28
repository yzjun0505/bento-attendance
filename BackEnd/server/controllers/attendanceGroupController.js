/**
 * 考勤组管理控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');

/**
 * 获取考勤组列表
 * GET /api/attendance-groups
 */
async function getGroups(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { keyword, status, project_id } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (keyword) {
      where += ' AND ag.name LIKE ?';
      params.push(`%${keyword}%`);
    }
    if (status !== undefined && status !== '') {
      where += ' AND ag.status = ?';
      params.push(parseInt(status));
    }
    if (project_id) {
      where += ' AND ag.project_id = ?';
      params.push(parseInt(project_id));
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM attendance_groups ag ${where}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT ag.*, ag.work_start_time as start_time, ag.work_end_time as end_time,
        ag.early_leave_tolerance,
        p.name as project_name,
        (SELECT COUNT(*) FROM attendance_group_members WHERE group_id = ag.id) as member_count
       FROM attendance_groups ag
       LEFT JOIN projects p ON ag.project_id = p.id
       ${where}
       ORDER BY ag.created_at DESC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({ list: rows, total, page, pageSize }));
  } catch (err) {
    console.error('获取考勤组列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单个考勤组详情（含成员列表）
 * GET /api/attendance-groups/:id
 */
async function getGroupById(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      `SELECT ag.*, ag.work_start_time as start_time, ag.work_end_time as end_time,
        ag.early_leave_tolerance,
        p.name as project_name
       FROM attendance_groups ag
       LEFT JOIN projects p ON ag.project_id = p.id
       WHERE ag.id = ?`,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('考勤组不存在', 404));
    }

    const group = rows[0];

    const [members] = await db.execute(
      `SELECT agm.user_id, agm.created_at, u.name as user_name, u.username, u.phone, u.email
       FROM attendance_group_members agm
       LEFT JOIN users u ON agm.user_id = u.id
       WHERE agm.group_id = ?`,
      [req.params.id]
    );

    group.members = members;

    res.json(successResponse(group));
  } catch (err) {
    console.error('获取考勤组详情失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建考勤组
 * POST /api/attendance-groups
 */
async function createGroup(req, res) {
  try {
    const { name, start_time, end_time, late_tolerance, project_id, status, user_ids, early_leave_tolerance } = req.body;
    if (!name || !start_time || !end_time) {
      return res.status(400).json(errorResponse('考勤组名称、上班时间、下班时间不能为空', 400));
    }

    const db = getPool();
    // 数据库实际列名: work_start_time, work_end_time, early_leave_tolerance
    // 前端传: start_time, end_time
    const [result] = await db.execute(
      'INSERT INTO attendance_groups (name, work_start_time, work_end_time, late_tolerance, early_leave_tolerance, project_id) VALUES (?, ?, ?, ?, ?, ?)',
      [name, start_time, end_time, late_tolerance || 0, early_leave_tolerance || 0, project_id || null]
    );

    const groupId = result.insertId;

    if (Array.isArray(user_ids) && user_ids.length > 0) {
      const values = user_ids.map(uid => [groupId, uid]);
      await db.query(
        'INSERT INTO attendance_group_members (group_id, user_id) VALUES ?',
        [values]
      );
    }

    res.json(successResponse({ id: groupId }, '考勤组创建成功'));
  } catch (err) {
    console.error('创建考勤组失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新考勤组
 * PUT /api/attendance-groups/:id
 */
async function updateGroup(req, res) {
  try {
    const { name, start_time, end_time, late_tolerance, early_leave_tolerance, project_id, status } = req.body;
    const db = getPool();

    const fields = [];
    const params = [];

    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    // 前端传 start_time/end_time，数据库列名是 work_start_time/work_end_time
    if (start_time !== undefined) { fields.push('work_start_time = ?'); params.push(start_time); }
    if (end_time !== undefined) { fields.push('work_end_time = ?'); params.push(end_time); }
    if (late_tolerance !== undefined) { fields.push('late_tolerance = ?'); params.push(late_tolerance); }
    if (early_leave_tolerance !== undefined) { fields.push('early_leave_tolerance = ?'); params.push(early_leave_tolerance); }
    if (project_id !== undefined) { fields.push('project_id = ?'); params.push(project_id || null); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE attendance_groups SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '考勤组更新成功'));
  } catch (err) {
    console.error('更新考勤组失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除考勤组
 * DELETE /api/attendance-groups/:id
 */
async function deleteGroup(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute('SELECT id FROM attendance_groups WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('考勤组不存在', 404));
    }

    await db.execute('DELETE FROM attendance_groups WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '考勤组删除成功'));
  } catch (err) {
    console.error('删除考勤组失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 批量添加成员
 * POST /api/attendance-groups/:id/members
 */
async function addMembers(req, res) {
  try {
    const { user_ids } = req.body;
    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return res.status(400).json(errorResponse('请选择要添加的成员', 400));
    }

    const db = getPool();
    const groupId = req.params.id;

    const [groupRows] = await db.execute('SELECT id FROM attendance_groups WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json(errorResponse('考勤组不存在', 404));
    }

    const values = user_ids.map(uid => [groupId, uid]);
    await db.query(
      'INSERT IGNORE INTO attendance_group_members (group_id, user_id) VALUES ?',
      [values]
    );

    res.json(successResponse(null, '成员添加成功'));
  } catch (err) {
    console.error('添加成员失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 移除成员
 * DELETE /api/attendance-groups/:id/members/:userId
 */
async function removeMember(req, res) {
  try {
    const db = getPool();
    await db.execute(
      'DELETE FROM attendance_group_members WHERE group_id = ? AND user_id = ?',
      [req.params.id, req.params.userId]
    );

    res.json(successResponse(null, '成员移除成功'));
  } catch (err) {
    console.error('移除成员失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取当前用户所属考勤组
 * GET /api/attendance-groups/my
 */
async function getMyGroup(req, res) {
  try {
    const userId = req.user.id;
    const db = getPool();

    // 通过 attendance_group_members 查找用户所属考勤组
    const [rows] = await db.execute(
      `SELECT ag.*, ag.work_start_time as start_time, ag.work_end_time as end_time,
        ag.early_leave_tolerance,
        p.name as project_name
       FROM attendance_group_members agm
       JOIN attendance_groups ag ON agm.group_id = ag.id
       LEFT JOIN projects p ON ag.project_id = p.id
       WHERE agm.user_id = ? AND ag.status = 1
       ORDER BY ag.created_at DESC
       LIMIT 1`,
      [userId]
    );

    if (rows.length === 0) {
      return res.json(successResponse(null));
    }

    const group = rows[0];

    // 获取考勤组成员数
    const [countRows] = await db.execute(
      'SELECT COUNT(*) as member_count FROM attendance_group_members WHERE group_id = ?',
      [group.id]
    );
    group.member_count = countRows[0].member_count;

    res.json(successResponse(group));
  } catch (err) {
    console.error('获取当前用户考勤组失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getGroups, getGroupById, getMyGroup, createGroup, updateGroup, deleteGroup, addMembers, removeMember };
