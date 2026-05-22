/**
 * 项目进度控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse } = require('../utils/helpers');
const { getAccessibleProjectIds, canAccessProject } = require('../middleware/authScope');

/**
 * 获取项目进度工作台数据
 * GET /api/progress/workbench
 */
async function getWorkbench(req, res) {
  try {
    const db = getPool();
    const projectIds = await getAccessibleProjectIds(req);

    if (projectIds.length === 0) {
      return res.json(successResponse({ projects: [] }));
    }

    const placeholders = projectIds.map(() => '?').join(',');
    const [projects] = await db.query(
      `SELECT id, name, address, status FROM projects WHERE id IN (${placeholders}) ORDER BY name`,
      projectIds
    );

    const result = [];
    for (const project of projects) {
      const [[stats]] = await db.query(`
        SELECT
          COUNT(*) as totalNodes,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedNodes,
          SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as inProgressNodes,
          SUM(CASE WHEN plan_end_date < CURDATE() AND status != 'completed' THEN 1 ELSE 0 END) as overdueNodes,
          SUM(CASE WHEN status = 'paused' THEN 1 ELSE 0 END) as pausedNodes,
          ROUND(AVG(progress_percent), 1) as overallProgress
        FROM task_nodes WHERE project_id = ?
      `, [project.id]);

      const [[lastReport]] = await db.query(`
        SELECT MAX(pr.created_at) as lastTime
        FROM progress_reports pr
        INNER JOIN task_nodes tn ON pr.node_id = tn.id
        WHERE tn.project_id = ?
      `, [project.id]);

      const [[assignee]] = await db.query(`
        SELECT COUNT(DISTINCT assignee_id) as count
        FROM task_nodes WHERE project_id = ? AND assignee_id IS NOT NULL
      `, [project.id]);

      result.push({
        id: project.id,
        name: project.name,
        address: project.address,
        status: project.status,
        overallProgress: Math.round(stats.overallProgress || 0),
        totalNodes: stats.totalNodes || 0,
        completedNodes: stats.completedNodes || 0,
        inProgressNodes: stats.inProgressNodes || 0,
        overdueNodes: stats.overdueNodes || 0,
        pausedNodes: stats.pausedNodes || 0,
        lastReportTime: lastReport.lastTime || null,
        assigneeCount: assignee.count || 0,
      });
    }

    res.json(successResponse({ projects: result }));
  } catch (err) {
    console.error('获取工作台数据失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单项目进度摘要
 * GET /api/projects/:projectId/progress-summary
 */
async function getProjectSummary(req, res) {
  try {
    const db = getPool();
    const { projectId } = req.params;

    const [projRows] = await db.execute('SELECT id, name FROM projects WHERE id = ?', [projectId]);
    if (projRows.length === 0) {
      return res.status(400).json(errorResponse('项目不存在', 400));
    }
    if (!(await canAccessProject(req, projectId))) {
      return res.status(403).json(errorResponse('无权限访问该项目', 403));
    }

    const [[stats]] = await db.query(`
      SELECT
        COUNT(*) as totalNodes,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedNodes,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as inProgressNodes,
        SUM(CASE WHEN plan_end_date < CURDATE() AND status != 'completed' THEN 1 ELSE 0 END) as overdueNodes,
        SUM(CASE WHEN status = 'paused' THEN 1 ELSE 0 END) as pausedNodes,
        ROUND(AVG(progress_percent), 1) as overallProgress
      FROM task_nodes WHERE project_id = ?
    `, [projectId]);

    const phases = ['preparation', 'construction', 'inspection', 'rectification', 'delivery'];
    const phaseLabels = {
      preparation: '准备阶段',
      construction: '施工阶段',
      inspection: '验收阶段',
      rectification: '整改阶段',
      delivery: '交付阶段'
    };
    const phaseStats = [];
    for (const phase of phases) {
      const [[ps]] = await db.query(`
        SELECT
          COUNT(*) as nodeCount,
          SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedCount
        FROM task_nodes WHERE project_id = ? AND phase = ?
      `, [projectId, phase]);
      phaseStats.push({
        phase,
        label: phaseLabels[phase],
        nodeCount: ps.nodeCount || 0,
        completedCount: ps.completedCount || 0,
        completionRate: ps.nodeCount > 0 ? Math.round((ps.completedCount / ps.nodeCount) * 100) : 0,
      });
    }

    const [reports] = await db.query(`
      SELECT pr.id, pr.node_id as nodeId, pr.description, pr.photo,
             pr.progress_percent as progressPercent,
             pr.risk_note as riskNote, pr.blocker_note as blockerNote,
             pr.photos, pr.created_at as createdAt,
             u.name as reporterName, tn.title as nodeTitle
      FROM progress_reports pr
      INNER JOIN task_nodes tn ON pr.node_id = tn.id
      LEFT JOIN users u ON pr.reporter_id = u.id
      WHERE tn.project_id = ?
      ORDER BY pr.created_at DESC LIMIT 10
    `, [projectId]);

    res.json(successResponse({
      projectId: parseInt(projectId),
      projectName: projRows[0].name,
      overallProgress: Math.round(stats.overallProgress || 0),
      totalNodes: stats.totalNodes || 0,
      completedNodes: stats.completedNodes || 0,
      inProgressNodes: stats.inProgressNodes || 0,
      overdueNodes: stats.overdueNodes || 0,
      pausedNodes: stats.pausedNodes || 0,
      phases: phaseStats,
      recentReports: reports,
    }));
  } catch (err) {
    console.error('获取项目摘要失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { getWorkbench, getProjectSummary };
