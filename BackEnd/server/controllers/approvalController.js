/**
 * 审批管理控制器
 */
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination } = require('../utils/helpers');

const APPROVAL_TYPES = ['补卡', '请假', '加班'];
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

    const db = getPool();
    const [result] = await db.execute(
      'INSERT INTO approval_requests (user_id, type, reason, start_date, end_date) VALUES (?, ?, ?, ?, ?)',
      [user_id, type, reason, start_date, end_date || start_date]
    );

    res.json(successResponse({ id: result.insertId }, '申请提交成功'));
  } catch (err) {
    console.error('创建审批申请失败:', err);
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
    console.error('获取待审批列表失败:', err);
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
    console.error('获取我的申请列表失败:', err);
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
    console.error('获取审批列表失败:', err);
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

    if (approval.type === '补卡') {
      const dateStr = new Date(approval.start_date).toISOString().slice(0, 10);
      const [existing] = await db.execute(
        'SELECT id FROM attendance_results WHERE user_id = ? AND date = ?',
        [approval.user_id, dateStr]
      );

      if (existing.length > 0) {
        await db.execute(
          'UPDATE attendance_results SET status = ? WHERE id = ?',
          ['normal', existing[0].id]
        );
      } else {
        await db.execute(
          'INSERT INTO attendance_results (user_id, date, status) VALUES (?, ?, ?)',
          [approval.user_id, dateStr, 'normal']
        );
      }
    } else if (approval.type === '请假') {
      const startDate = new Date(approval.start_date);
      const endDate = approval.end_date ? new Date(approval.end_date) : startDate;

      for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
        const dateStr = d.toISOString().slice(0, 10);
        const [existing] = await db.execute(
          'SELECT id FROM attendance_results WHERE user_id = ? AND date = ?',
          [approval.user_id, dateStr]
        );

        if (existing.length > 0) {
          await db.execute(
            'UPDATE attendance_results SET status = ? WHERE id = ?',
            ['leave', existing[0].id]
          );
        } else {
          await db.execute(
            'INSERT INTO attendance_results (user_id, date, status) VALUES (?, ?, ?)',
            [approval.user_id, dateStr, 'leave']
          );
        }
      }
    }

    res.json(successResponse(null, '审批通过'));
  } catch (err) {
    console.error('审批通过失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
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

    res.json(successResponse(null, '审批已驳回'));
  } catch (err) {
    console.error('审批驳回失败:', err);
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

    await db.execute('DELETE FROM approval_requests WHERE id = ?', [approvalId]);

    res.json(successResponse(null, '审批单已删除'));
  } catch (err) {
    console.error('删除审批单失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = {
  createApproval,
  getPendingApprovals,
  getMyApprovals,
  getAllApprovals,
  approveApproval,
  rejectApproval,
  deleteApproval
};
