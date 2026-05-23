/**
 * 审批管理控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');
const logger = require('../utils/logger');
const notificationService = require('../services/notificationService');

const OUTSIDE_CHECKIN_APPROVAL_TYPE = '异常打卡';
const APPROVAL_TYPES = ['补卡', '请假', '加班', OUTSIDE_CHECKIN_APPROVAL_TYPE];
const APPROVAL_STATUS = ['pending', 'approved', 'rejected'];

async function createApproval(req, res) {
  try {
    const { type, reason, start_date, end_date } = req.body;
    const user_id = req.user.id;

    if (!type || !reason || !start_date) {
      return res.status(400).json(errorResponse('申请类型、原因、开始日期不能为空', 400));
    }

    if (!APPROVAL_TYPES.includes(type)) {
      return res.status(400).json(errorResponse('申请类型无效', 400));
    }
    if (type === OUTSIDE_CHECKIN_APPROVAL_TYPE) {
      return res.status(400).json(errorResponse('异常打卡审批由系统自动生成', 400));
    }

    const db = getPool();
    const [result] = await db.execute(
      'INSERT INTO approval_requests (user_id, type, reason, start_date, end_date) VALUES (?, ?, ?, ?, ?)',
      [user_id, type, reason, start_date, end_date || start_date]
    );

    notifyManagersForApprovalRequest(db, {
      approvalId: result.insertId,
      userId: user_id,
      type,
      reason,
      startDate: start_date,
      endDate: end_date || start_date,
    });

    res.json(successResponse({ id: result.insertId }, '申请提交成功'));
  } catch (err) {
    logger.error('创建审批申请失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function getPendingApprovals(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);

    const [countRows] = await db.execute(
      'SELECT COUNT(*) as total FROM approval_requests WHERE status = ?',
      ['pending']
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT ar.*, u.name as user_name, u.username, u.phone, p.name as project_name
       FROM approval_requests ar
       LEFT JOIN users u ON ar.user_id = u.id
       LEFT JOIN projects p ON u.project_id = p.id
       WHERE ar.status = ?
       ORDER BY ar.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
      ['pending']
    );

    res.json(successResponse({ list: rows, total, page, pageSize }));
  } catch (err) {
    logger.error('获取待审批列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function getMyApprovals(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const user_id = req.user.id;

    const [countRows] = await db.execute(
      'SELECT COUNT(*) as total FROM approval_requests WHERE user_id = ?',
      [user_id]
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT ar.*, appr.name as approver_name
       FROM approval_requests ar
       LEFT JOIN users appr ON ar.approver_id = appr.id
       WHERE ar.user_id = ?
       ORDER BY ar.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
      [user_id]
    );

    res.json(successResponse({ list: rows, total, page, pageSize }));
  } catch (err) {
    logger.error('获取我的申请列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function getAllApprovals(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { status, type } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (status && APPROVAL_STATUS.includes(status)) {
      where += ' AND ar.status = ?';
      params.push(status);
    }
    if (type && APPROVAL_TYPES.includes(type)) {
      where += ' AND ar.type = ?';
      params.push(type);
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM approval_requests ar ${where}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT ar.*, u.name as user_name, u.username, u.phone, p.name as project_name, appr.name as approver_name
       FROM approval_requests ar
       LEFT JOIN users u ON ar.user_id = u.id
       LEFT JOIN projects p ON u.project_id = p.id
       LEFT JOIN users appr ON ar.approver_id = appr.id
       ${where}
       ORDER BY ar.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
      params
    );

    res.json(successResponse({ list: rows, total, page, pageSize }));
  } catch (err) {
    logger.error('获取审批列表失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function approveApproval(req, res) {
  try {
    const db = getPool();
    const { remark } = req.body;
    const approvalId = req.params.id;
    const approver_id = req.user.id;

    const [rows] = await db.execute(
      'SELECT * FROM approval_requests WHERE id = ?',
      [approvalId]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('审批单不存在', 404));
    }

    const approval = rows[0];
    if (approval.status !== 'pending') {
      return res.status(400).json(errorResponse('该审批单已处理', 400));
    }

    await db.execute(
      'UPDATE approval_requests SET status = ?, approver_id = ?, approved_at = NOW(), remark = ? WHERE id = ?',
      ['approved', approver_id, remark || null, approvalId]
    );

    // 审批通过后联动考勤结果
    if (approval.type === '补卡') {
      const dateStr = formatLocalDate(approval.start_date);
      await upsertAttendanceResult(db, approval.user_id, dateStr, 'normal');
    } else if (approval.type === '请假') {
      const startDate = new Date(approval.start_date + 'T00:00:00');
      const endDate = approval.end_date ? new Date(approval.end_date + 'T00:00:00') : startDate;

      for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
        const dateStr = formatLocalDate(d);
        await upsertAttendanceResult(db, approval.user_id, dateStr, 'leave');
      }
    } else if (approval.type === '加班') {
      // 加班审批通过后，标记对应日期有加班记录
      const startDate = new Date(approval.start_date + 'T00:00:00');
      const endDate = approval.end_date ? new Date(approval.end_date + 'T00:00:00') : startDate;

      for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
        const dateStr = formatLocalDate(d);
        // 加班不影响正常考勤状态，但记录加班标记
        await upsertAttendanceResult(db, approval.user_id, dateStr, null, { overtime: true });
      }
    } else if (approval.type === OUTSIDE_CHECKIN_APPROVAL_TYPE) {
      await updateOutsideCheckinApproval(db, approval, 'approved');
    }

    await notifyApprovalResult(approval, 'approved', remark);
    res.json(successResponse(null, '审批通过'));
  } catch (err) {
    logger.error('审批通过失败', { error: err.message, approvalId });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 格式化日期为本地时间字符串 YYYY-MM-DD
 */
function formatLocalDate(dateInput) {
  const d = new Date(dateInput);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * 插入或更新考勤结果
 */
async function upsertAttendanceResult(db, userId, date, status, extra = {}) {
  const [existing] = await db.execute(
    'SELECT id, status FROM attendance_results WHERE user_id = ? AND date = ?',
    [userId, date]
  );

  if (existing.length > 0) {
    const updates = [];
    const params = [];
    if (status) {
      updates.push('status = ?');
      params.push(status);
    }
    if (extra.overtime) {
      updates.push('overtime = ?');
      params.push(1);
    }
    if (updates.length > 0) {
      params.push(existing[0].id);
      await db.execute(`UPDATE attendance_results SET ${updates.join(', ')} WHERE id = ?`, params);
    }
  } else {
    const fields = ['user_id', 'date'];
    const placeholders = ['?', '?'];
    const values = [userId, date];
    if (status) {
      fields.push('status');
      placeholders.push('?');
      values.push(status);
    }
    if (extra.overtime) {
      fields.push('overtime');
      placeholders.push('?');
      values.push(1);
    }
    await db.execute(
      `INSERT INTO attendance_results (${fields.join(', ')}) VALUES (${placeholders.join(', ')})`,
      values
    );
  }
}

async function notifyManagersForApprovalRequest(db, { approvalId, userId, type, reason, startDate, endDate }) {
  try {
    const [managerRows] = await db.execute(
      `SELECT id FROM users WHERE status = 1 AND role IN ('admin', 'manager')`
    );
    const managerIds = managerRows.map((row) => row.id).filter((id) => Number(id) !== Number(userId));
    if (managerIds.length === 0) return;

    await notificationService.createNotificationForUsers(managerIds, {
      title: `${type}申请待审批`,
      content: `审批 #${approvalId} 需要处理，日期：${startDate}${endDate && endDate !== startDate ? ` 至 ${endDate}` : ''}，原因：${reason}`,
      type: 'system',
    });
  } catch (err) {
    logger.warn('发送审批待办通知失败(忽略)', {
      approvalId,
      error: err.message,
    });
  }
}

async function updateOutsideCheckinApproval(db, approval, status) {
  if (!approval.checkin_id) {
    logger.warn('异常打卡审批缺少关联打卡记录', { approvalId: approval.id });
    return;
  }

  const [result] = await db.execute(
    `UPDATE checkins
     SET outside_approval_status = ?
     WHERE id = ? AND approval_request_id = ?`,
    [status, approval.checkin_id, approval.id]
  );

  if (result.affectedRows === 0) {
    logger.warn('异常打卡审批未能回写打卡记录', {
      approvalId: approval.id,
      checkinId: approval.checkin_id,
      status,
    });
  }
}

async function notifyApprovalResult(approval, status, remark) {
  try {
    const approved = status === 'approved';
    const title = approved ? '审批已通过' : '审批已驳回';
    const contentParts = [
      `你的${approval.type}申请${approved ? '已通过' : '已驳回'}。`,
    ];
    if (approval.type === OUTSIDE_CHECKIN_APPROVAL_TYPE && approval.checkin_id) {
      contentParts.push(`关联打卡记录：#${approval.checkin_id}。`);
    }
    if (remark) {
      contentParts.push(`备注：${remark}`);
    }

    await notificationService.createNotification({
      user_id: approval.user_id,
      title,
      content: contentParts.join(''),
      type: approval.type === OUTSIDE_CHECKIN_APPROVAL_TYPE ? 'checkin' : 'system',
    });
  } catch (err) {
    logger.warn('发送审批结果通知失败(忽略)', {
      approvalId: approval.id,
      error: err.message,
    });
  }
}

async function rejectApproval(req, res) {
  try {
    const db = getPool();
    const { remark } = req.body;
    const approvalId = req.params.id;
    const approver_id = req.user.id;

    const [rows] = await db.execute(
      'SELECT * FROM approval_requests WHERE id = ?',
      [approvalId]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('审批单不存在', 404));
    }

    const approval = rows[0];
    if (approval.status !== 'pending') {
      return res.status(400).json(errorResponse('该审批单已处理', 400));
    }

    await db.execute(
      'UPDATE approval_requests SET status = ?, approver_id = ?, remark = ? WHERE id = ?',
      ['rejected', approver_id, remark || null, approvalId]
    );

    if (approval.type === OUTSIDE_CHECKIN_APPROVAL_TYPE) {
      await updateOutsideCheckinApproval(db, approval, 'rejected');
    }

    await notifyApprovalResult(approval, 'rejected', remark);
    res.json(successResponse(null, '审批已驳回'));
  } catch (err) {
    logger.error('审批驳回失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取单条审批详情（含关联打卡记录）
 * GET /api/approvals/:id
 */
async function getApprovalById(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      `SELECT ar.*, u.name as user_name, u.username, u.phone,
              p.name as project_name, appr.name as approver_name
       FROM approval_requests ar
       LEFT JOIN users u ON ar.user_id = u.id
       LEFT JOIN projects p ON u.project_id = p.id
       LEFT JOIN users appr ON ar.approver_id = appr.id
       WHERE ar.id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('审批单不存在', 404));
    }

    const approval = rows[0];

    // 如果关联了打卡记录，查询详情
    let checkin = null;
    if (approval.checkin_id) {
      const [cRows] = await db.query(
        `SELECT c.*, u2.name as user_name
         FROM checkins c
         LEFT JOIN users u2 ON c.user_id = u2.id
         WHERE c.id = ?`,
        [approval.checkin_id]
      );
      if (cRows.length > 0) checkin = cRows[0];
    }

    res.json(successResponse({
      ...approval,
      checkin,
    }));
  } catch (err) {
    logger.error('获取审批详情失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function deleteApproval(req, res) {
  try {
    const db = getPool();
    const approvalId = req.params.id;
    const user_id = req.user.id;

    const [rows] = await db.execute(
      'SELECT * FROM approval_requests WHERE id = ? AND user_id = ?',
      [approvalId, user_id]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('审批单不存在或无权删除', 404));
    }

    if (rows[0].status !== 'pending') {
      return res.status(400).json(errorResponse('已处理的审批单不能删除', 400));
    }
    if (rows[0].type === OUTSIDE_CHECKIN_APPROVAL_TYPE) {
      return res.status(400).json(errorResponse('异常打卡审批不能由员工删除', 400));
    }

    await db.execute('DELETE FROM approval_requests WHERE id = ?', [approvalId]);

    res.json(successResponse(null, '审批单已删除'));
  } catch (err) {
    logger.error('删除审批单失败', { error: err.message });
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = {
  createApproval,
  getPendingApprovals,
  getMyApprovals,
  getAllApprovals,
  getApprovalById,
  approveApproval,
  rejectApproval,
  deleteApproval
};
