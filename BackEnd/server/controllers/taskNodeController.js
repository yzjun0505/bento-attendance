/**
 * 任务节点与进度上报控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const { canAccessProject } = require('../middleware/authScope');

function normalizePhotos(photos) {
  if (!photos) return null;
  if (Array.isArray(photos)) return JSON.stringify(photos);
  if (typeof photos === 'string') {
    try {
      const parsed = JSON.parse(photos);
      return Array.isArray(parsed) ? JSON.stringify(parsed) : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/**
 * 获取项目的任务节点列表（支持筛选）
 * GET /api/projects/:projectId/nodes
 */
async function getNodesByProject(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { projectId } = req.params;
    const { phase, status, assignee_id } = req.query;

    const [projectRows] = await db.execute('SELECT id FROM projects WHERE id = ?', [projectId]);
    if (projectRows.length === 0) {
      return res.status(400).json(errorResponse('项目不存在', 400));
    }
    if (!(await canAccessProject(req, projectId))) {
      return res.status(403).json(errorResponse('无权限访问该项目', 403));
    }

    let whereClause = 'WHERE tn.project_id = ?';
    const params = [projectId];

    if (phase) {
      whereClause += ' AND tn.phase = ?';
      params.push(phase);
    }
    if (status) {
      whereClause += ' AND tn.status = ?';
      params.push(status);
    }
    if (assignee_id) {
      whereClause += ' AND tn.assignee_id = ?';
      params.push(assignee_id);
    }

    const [countRows] = await db.query(
      `SELECT COUNT(*) as total FROM task_nodes tn ${whereClause}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT tn.id, tn.project_id, tn.title, tn.description, tn.planned_date,
              tn.assignee_id, tn.status, tn.progress_percent,
              tn.phase, tn.plan_start_date, tn.plan_end_date, tn.priority, tn.sort_order,
              tn.created_at, tn.updated_at,
              u.name as assignee_name
       FROM task_nodes tn
       LEFT JOIN users u ON tn.assignee_id = u.id
       ${whereClause}
       ORDER BY tn.sort_order ASC, tn.created_at DESC
       LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    res.json(successResponse({
      list: rows,
      total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取任务节点列表失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 创建任务节点（含权限校验）
 * POST /api/projects/:projectId/nodes
 */
async function createNode(req, res) {
  try {
    const { projectId } = req.params;
    const {
      title, description, planned_date, status, progress_percent,
      phase, priority, sort_order
    } = req.body;
    const assigneeId = req.body.assignee_id ?? req.body.assigneeId;
    const planStartDate = req.body.plan_start_date ?? req.body.planStartDate;
    const planEndDate = req.body.plan_end_date ?? req.body.planEndDate;

    if (!title) {
      return res.status(400).json(errorResponse('任务标题不能为空', 400));
    }

    const db = getPool();

    const [projectRows] = await db.execute('SELECT id FROM projects WHERE id = ?', [projectId]);
    if (projectRows.length === 0) {
      return res.status(400).json(errorResponse('项目不存在', 400));
    }

    if (!(await canAccessProject(req, projectId))) {
      return res.status(403).json(errorResponse('无权限创建该项目节点', 403));
    }

    const [result] = await db.execute(
      `INSERT INTO task_nodes
       (project_id, title, description, planned_date, assignee_id, status, progress_percent,
        phase, plan_start_date, plan_end_date, priority, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        projectId,
        title,
        description || null,
        planned_date || null,
        assigneeId || null,
        status || 'pending',
        progress_percent || 0,
        phase || null,
        planStartDate || null,
        planEndDate || null,
        priority || null,
        sort_order !== undefined ? sort_order : 0
      ]
    );

    const [newNode] = await db.query(
      `SELECT tn.*, u.name as assignee_name
       FROM task_nodes tn
       LEFT JOIN users u ON tn.assignee_id = u.id
       WHERE tn.id = ?`,
      [result.insertId]
    );

    res.json(successResponse(newNode[0], '创建成功'));
  } catch (err) {
    console.error('创建任务节点失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 更新任务节点
 * PUT /api/nodes/:id
 */
async function updateNode(req, res) {
  try {
    const {
      title, description, planned_date, status, progress_percent,
      phase, priority, sort_order
    } = req.body;
    const assigneeId = req.body.assignee_id ?? req.body.assigneeId;
    const planStartDate = req.body.plan_start_date ?? req.body.planStartDate;
    const planEndDate = req.body.plan_end_date ?? req.body.planEndDate;
    const db = getPool();

    const [existing] = await db.execute('SELECT id, project_id FROM task_nodes WHERE id = ?', [req.params.id]);
    if (existing.length === 0) {
      return res.status(404).json(errorResponse('任务节点不存在', 404));
    }
    if (!(await canAccessProject(req, existing[0].project_id))) {
      return res.status(403).json(errorResponse('无权限操作该任务节点', 403));
    }

    const fields = [];
    const params = [];

    if (title !== undefined) { fields.push('title = ?'); params.push(title); }
    if (description !== undefined) { fields.push('description = ?'); params.push(description); }
    if (planned_date !== undefined) { fields.push('planned_date = ?'); params.push(planned_date || null); }
    if (assigneeId !== undefined) { fields.push('assignee_id = ?'); params.push(assigneeId || null); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (progress_percent !== undefined) { fields.push('progress_percent = ?'); params.push(progress_percent); }
    if (phase !== undefined) { fields.push('phase = ?'); params.push(phase); }
    if (planStartDate !== undefined) { fields.push('plan_start_date = ?'); params.push(planStartDate || null); }
    if (planEndDate !== undefined) { fields.push('plan_end_date = ?'); params.push(planEndDate || null); }
    if (priority !== undefined) { fields.push('priority = ?'); params.push(priority); }
    if (sort_order !== undefined) { fields.push('sort_order = ?'); params.push(sort_order); }

    if (fields.length === 0) {
      return res.status(400).json(errorResponse('没有可更新的字段', 400));
    }

    params.push(req.params.id);
    await db.execute(`UPDATE task_nodes SET ${fields.join(', ')} WHERE id = ?`, params);

    res.json(successResponse(null, '任务节点更新成功'));
  } catch (err) {
    console.error('更新任务节点失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 删除任务节点
 * DELETE /api/nodes/:id
 */
async function deleteNode(req, res) {
  try {
    const db = getPool();

    const [existing] = await db.execute('SELECT id, project_id FROM task_nodes WHERE id = ?', [req.params.id]);
    if (existing.length === 0) {
      return res.status(404).json(errorResponse('任务节点不存在', 404));
    }
    if (!(await canAccessProject(req, existing[0].project_id))) {
      return res.status(403).json(errorResponse('无权限操作该任务节点', 403));
    }

    await db.execute('DELETE FROM task_nodes WHERE id = ?', [req.params.id]);
    res.json(successResponse(null, '任务节点删除成功'));
  } catch (err) {
    console.error('删除任务节点失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取节点的进度上报记录
 * GET /api/nodes/:id/reports
 */
async function getReportsByNode(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);

    const [nodeRows] = await db.execute('SELECT id, project_id FROM task_nodes WHERE id = ?', [req.params.id]);
    if (nodeRows.length === 0) {
      return res.status(404).json(errorResponse('任务节点不存在', 404));
    }
    if (!(await canAccessProject(req, nodeRows[0].project_id))) {
      return res.status(403).json(errorResponse('无权限访问该任务节点', 403));
    }

    const [countRows] = await db.execute(
      'SELECT COUNT(*) as total FROM progress_reports WHERE node_id = ?',
      [req.params.id]
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT pr.id, pr.node_id, pr.reporter_id, pr.description, pr.photo,
              pr.progress_percent, pr.risk_note, pr.blocker_note, pr.photos,
              pr.created_at, u.name as reporter_name
       FROM progress_reports pr
       LEFT JOIN users u ON pr.reporter_id = u.id
       WHERE pr.node_id = ?
       ORDER BY pr.created_at DESC
       LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      [req.params.id]
    );

    res.json(successResponse({
      list: rows,
      total,
      page,
      pageSize
    }));
  } catch (err) {
    console.error('获取进度上报记录失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 提交进度上报（含增强字段与节点进度更新）
 * POST /api/nodes/:id/reports
 */
async function createReport(req, res) {
  try {
    const { description, photo, progress_percent, risk_note, blocker_note, photos } = req.body;
    const nodeId = req.params.id;

    if (progress_percent === undefined || progress_percent === null) {
      return res.status(400).json(errorResponse('进度百分比不能为空', 400));
    }

    const db = getPool();

    const [nodeRows] = await db.execute('SELECT id, project_id FROM task_nodes WHERE id = ?', [nodeId]);
    if (nodeRows.length === 0) {
      return res.status(404).json(errorResponse('任务节点不存在', 404));
    }
    if (!(await canAccessProject(req, nodeRows[0].project_id))) {
      return res.status(403).json(errorResponse('无权限访问该任务节点', 403));
    }

    const reporterId = req.user.id;
    const normalizedPhotos = normalizePhotos(photos);

    const [result] = await db.execute(
      `INSERT INTO progress_reports
       (node_id, reporter_id, description, photo, progress_percent, risk_note, blocker_note, photos)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        nodeId,
        reporterId,
        description || null,
        photo || null,
        progress_percent,
        risk_note || null,
        blocker_note || null,
        normalizedPhotos
      ]
    );

    // 更新进度 + 自动状态流转
    if (progress_percent >= 100) {
      await db.execute(
        'UPDATE task_nodes SET progress_percent = ?, status = ? WHERE id = ?',
        [100, 'completed', nodeId]
      );
    } else if (progress_percent > 0) {
      // >0% 且未完成：状态 from pending → in_progress
      await db.execute(
        "UPDATE task_nodes SET progress_percent = ?, status = IF(status = 'pending', 'in_progress', status) WHERE id = ?",
        [progress_percent, nodeId]
      );
    } else {
      await db.execute(
        'UPDATE task_nodes SET progress_percent = ? WHERE id = ?',
        [progress_percent, nodeId]
      );
    }

    const [reportRows] = await db.query(
      `SELECT pr.id, pr.node_id, pr.reporter_id, pr.description, pr.photo,
              pr.progress_percent, pr.risk_note, pr.blocker_note, pr.photos,
              pr.created_at, u.name as reporter_name
       FROM progress_reports pr
       LEFT JOIN users u ON pr.reporter_id = u.id
       WHERE pr.id = ?`,
      [result.insertId]
    );

    res.json(successResponse(reportRows[0], '进度上报成功'));
  } catch (err) {
    console.error('提交进度上报失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getNodesByProject, createNode, updateNode, deleteNode, getReportsByNode, createReport };
