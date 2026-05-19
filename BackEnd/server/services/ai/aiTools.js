const { getPool } = require('../../models/db');
const notificationService = require('../notificationService');
const permissions = require('./aiPermissions');

const CHECKIN_IN_TYPES = ['in', 'clock_in'];
const CHECKIN_OUT_TYPES = ['out', 'clock_out'];

function pad(n) {
  return String(n).padStart(2, '0');
}

function formatDateTime(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function formatDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function parseDateRange(message = '', context = {}) {
  const filters = context.filters || {};
  if (filters.date_start && filters.date_end) {
    return { start: filters.date_start, end: filters.date_end, label: '自定义时间' };
  }
  if (filters.date) {
    const d = new Date(filters.date);
    const start = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const end = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
    return { start: formatDateTime(start), end: formatDateTime(end), label: formatDate(start) };
  }

  const now = new Date();
  const normalized = String(message);
  const daysMatch = normalized.match(/最近\s*(\d+)\s*天/);
  if (daysMatch) {
    const days = Math.min(Math.max(Number(daysMatch[1]), 1), 90);
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - days + 1);
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    return { start: formatDateTime(start), end: formatDateTime(end), label: `最近${days}天` };
  }

  if (/昨天/.test(normalized)) {
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    return { start: formatDateTime(start), end: formatDateTime(end), label: '昨天' };
  }

  if (/本月|这个月|月度/.test(normalized)) {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return { start: formatDateTime(start), end: formatDateTime(end), label: '本月' };
  }

  if (/本周|这周|周报/.test(normalized)) {
    const day = now.getDay() || 7;
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - day + 1);
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    return { start: formatDateTime(start), end: formatDateTime(end), label: '本周' };
  }

  if (/今日|今天|当天/.test(normalized)) {
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    return { start: formatDateTime(start), end: formatDateTime(end), label: '今天' };
  }

  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  return { start: formatDateTime(start), end: formatDateTime(end), label: '最近7天' };
}

function toJson(value) {
  return JSON.stringify(value || {});
}

function fromJson(value) {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return {};
  }
}

function stripTrailingParticle(value = '') {
  return String(value).replace(/[的呢吗吧啊呀\s]+$/g, '').trim();
}

function buildChart(title, rows, nameKey, valueKey, chartType = 'bar') {
  return {
    title,
    chartType,
    xAxis: rows.map((row) => row[nameKey] || '未命名'),
    series: [
      {
        name: title,
        type: chartType,
        data: rows.map((row) => Number(row[valueKey] || 0)),
      },
    ],
  };
}

async function getDefaultStartTime(db) {
  const [rows] = await db.execute(
    `SELECT work_start_time FROM attendance_groups WHERE status = 1 ORDER BY id LIMIT 1`
  );
  return rows[0]?.work_start_time || '09:00:00';
}

async function getDashboardSummary(actor, context = {}, message = '') {
  const db = getPool();
  const range = parseDateRange(message, context);
  const userScope = permissions.scopeUserWhere(actor, 'u');
  const checkinScope = permissions.scopeCheckinWhere(actor, 'c');
  const approvalScope = permissions.scopeUserWhere(actor, 'u');

  const [userRows] = await db.execute(
    `SELECT COUNT(*) as total FROM users u WHERE u.status = 1${userScope.sql}`,
    userScope.params
  );
  const [attendanceRows] = await db.execute(
    `SELECT COUNT(DISTINCT c.user_id) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND c.type IN (?, ?)${checkinScope.sql}`,
    [range.start, range.end, ...CHECKIN_IN_TYPES, ...checkinScope.params]
  );
  const [abnormalRows] = await db.execute(
    `SELECT COUNT(*) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND (c.is_outside = 1 OR (c.type IN (?, ?) AND TIME(c.created_at) > ?))${checkinScope.sql}`,
    [range.start, range.end, ...CHECKIN_IN_TYPES, await getDefaultStartTime(db), ...checkinScope.params]
  );
  const [projectRows] = await db.execute(
    `SELECT COUNT(DISTINCT c.project_id) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND c.project_id IS NOT NULL${checkinScope.sql}`,
    [range.start, range.end, ...checkinScope.params]
  );
  const [pendingRows] = await db.execute(
    `SELECT COUNT(*) as total
     FROM approval_requests a
     JOIN users u ON a.user_id = u.id
     WHERE a.status = 'pending'${approvalScope.sql}`,
    approvalScope.params
  );

  const cards = [
    { label: '可见员工', value: userRows[0].total },
    { label: `${range.label}出勤`, value: attendanceRows[0].total },
    { label: `${range.label}异常`, value: abnormalRows[0].total },
    { label: '活跃项目', value: projectRows[0].total },
    { label: '待审批', value: pendingRows[0].total },
  ];

  return {
    type: 'summary',
    title: `${range.label}管理摘要`,
    range,
    cards,
    message: `${range.label}共有 ${attendanceRows[0].total} 人出勤，发现 ${abnormalRows[0].total} 条异常记录，当前还有 ${pendingRows[0].total} 条审批待处理。`,
  };
}

async function getAttendanceAnomalies(actor, context = {}, message = '') {
  const db = getPool();
  const range = parseDateRange(message, context);
  const scope = permissions.scopeCheckinWhere(actor, 'c');
  const defaultStartTime = await getDefaultStartTime(db);

  const [rows] = await db.execute(
    `SELECT c.id, u.name as userName, u.username, p.name as projectName,
            c.type, c.address, c.is_outside, c.distance_to_fence,
            DATE_FORMAT(c.created_at, '%Y-%m-%d %H:%i:%s') as createdAt,
            CASE
              WHEN c.is_outside = 1 THEN '围栏外打卡'
              WHEN c.type IN (?, ?) AND TIME(c.created_at) > ? THEN '迟到打卡'
              ELSE '异常记录'
            END as anomalyType
     FROM checkins c
     JOIN users u ON c.user_id = u.id
     LEFT JOIN projects p ON c.project_id = p.id
     WHERE c.created_at >= ? AND c.created_at < ?
       AND (c.is_outside = 1 OR (c.type IN (?, ?) AND TIME(c.created_at) > ?))${scope.sql}
     ORDER BY c.created_at DESC
     LIMIT 30`,
    [
      ...CHECKIN_IN_TYPES,
      defaultStartTime,
      range.start,
      range.end,
      ...CHECKIN_IN_TYPES,
      defaultStartTime,
      ...scope.params,
    ]
  );

  return {
    type: 'table',
    title: `${range.label}异常打卡`,
    range,
    message: `${range.label}共找到 ${rows.length} 条异常打卡记录。`,
    columns: [
      { prop: 'userName', label: '员工' },
      { prop: 'projectName', label: '项目' },
      { prop: 'anomalyType', label: '异常类型' },
      { prop: 'createdAt', label: '时间' },
      { prop: 'address', label: '地址' },
    ],
    rows,
  };
}

async function getProjectStats(actor, context = {}, message = '') {
  const db = getPool();
  const range = parseDateRange(message, context);
  const scope = permissions.scopeCheckinWhere(actor, 'c');

  const [rows] = await db.execute(
    `SELECT COALESCE(p.name, '未分配项目') as projectName,
            COUNT(*) as checkinCount,
            COUNT(DISTINCT c.user_id) as userCount,
            SUM(CASE WHEN c.is_outside = 1 THEN 1 ELSE 0 END) as outsideCount,
            MIN(DATE_FORMAT(c.created_at, '%Y-%m-%d')) as firstDate,
            MAX(DATE_FORMAT(c.created_at, '%Y-%m-%d')) as lastDate
     FROM checkins c
     LEFT JOIN projects p ON c.project_id = p.id
     WHERE c.created_at >= ? AND c.created_at < ?${scope.sql}
     GROUP BY c.project_id, p.name
     ORDER BY checkinCount DESC
     LIMIT 20`,
    [range.start, range.end, ...scope.params]
  );

  return {
    type: 'chart',
    title: `${range.label}项目外勤打卡统计`,
    range,
    message: `${range.label}共有 ${rows.length} 个项目产生打卡数据。`,
    columns: [
      { prop: 'projectName', label: '项目' },
      { prop: 'checkinCount', label: '打卡次数' },
      { prop: 'userCount', label: '打卡人数' },
      { prop: 'outsideCount', label: '围栏外' },
    ],
    rows,
    chart: buildChart('打卡次数', rows, 'projectName', 'checkinCount'),
  };
}

async function findVisibleUser(actor, keyword = '') {
  const db = getPool();
  const scope = permissions.scopeUserWhere(actor, 'u');
  const like = `%${keyword.trim()}%`;
  const params = keyword.trim()
    ? [like, like, ...scope.params]
    : [actor.id, ...scope.params];
  const condition = keyword.trim() ? '(u.name LIKE ? OR u.username LIKE ?)' : 'u.id = ?';
  const [rows] = await db.execute(
    `SELECT u.id, u.username, u.name, u.role, u.project_id, p.name as projectName
     FROM users u
     LEFT JOIN projects p ON u.project_id = p.id
     WHERE ${condition}${scope.sql}
     ORDER BY u.status DESC, u.id ASC
     LIMIT 1`,
    params
  );
  return rows[0] || null;
}

function extractPossibleName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:员工|人员|用户|工人)?\s*([一-龥A-Za-z0-9_]{2,20})\s*(?:的)?(?:最近|本周|本月|今天|考勤|打卡|记录|情况|迟到|是否|正常)/);
  if (!match) return '';
  const value = stripTrailingParticle(match[1]);
  if (/^(帮我|查询|看看|分析|总结|这个|今天|本周|本月|最近|员工)$/.test(value)) return '';
  return value;
}

function extractScheduleUserName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:把|给|为)\s*([一-龥A-Za-z0-9_]{2,20})(?:今天|明天|后天|\d{4}-\d{1,2}-\d{1,2}|安排|排班|设为|上)/);
  return match ? match[1] : '';
}

function extractShiftKeyword(message) {
  const text = String(message || '');
  return ['白班', '早班', '晚班', '夜班'].find((name) => text.includes(name)) || '';
}

async function getEmployeeAttendance(actor, context = {}, message = '') {
  const db = getPool();
  const range = parseDateRange(message, context);
  const keyword = context.employeeName || context.lastEmployeeName || extractPossibleName(message);
  const target = await findVisibleUser(actor, keyword);
  if (!target) {
    return {
      type: 'summary',
      title: '员工考勤查询',
      message: keyword ? `没有找到你有权限查看的员工：${keyword}。` : '没有找到可查看的员工。可以直接输入员工姓名再试一次。',
      cards: [],
    };
  }

  const [rows] = await db.execute(
    `SELECT c.id, c.type, c.address, c.is_outside, c.distance_to_fence,
            p.name as projectName,
            DATE_FORMAT(c.created_at, '%Y-%m-%d %H:%i:%s') as createdAt
     FROM checkins c
     LEFT JOIN projects p ON c.project_id = p.id
     WHERE c.user_id = ? AND c.created_at >= ? AND c.created_at < ?
     ORDER BY c.created_at DESC
     LIMIT 50`,
    [target.id, range.start, range.end]
  );

  const checkinCount = rows.length;
  const outsideCount = rows.filter((row) => Number(row.is_outside) === 1).length;
  const attendanceDays = new Set(rows.map((row) => String(row.createdAt).slice(0, 10))).size;

  return {
    type: 'table',
    title: `${target.name || target.username} ${range.label}考勤`,
    subject: {
      type: 'employee',
      id: target.id,
      name: target.name || target.username,
      username: target.username,
    },
    range,
    message: `${target.name || target.username} ${range.label}有 ${attendanceDays} 天产生打卡，共 ${checkinCount} 条记录，其中围栏外 ${outsideCount} 条。`,
    cards: [
      { label: '打卡天数', value: attendanceDays },
      { label: '打卡次数', value: checkinCount },
      { label: '围栏外', value: outsideCount },
      { label: '所属项目', value: target.projectName || '未分配' },
    ],
    columns: [
      { prop: 'createdAt', label: '时间' },
      { prop: 'type', label: '类型' },
      { prop: 'projectName', label: '项目' },
      { prop: 'address', label: '地址' },
      { prop: 'is_outside', label: '围栏外' },
    ],
    rows,
  };
}

async function getApprovalSummary(actor, context = {}, message = '') {
  const db = getPool();
  const scope = permissions.scopeUserWhere(actor, 'u');
  const status = /已通过|通过|approved/.test(message)
    ? 'approved'
    : /拒绝|驳回|rejected/.test(message)
      ? 'rejected'
      : 'pending';

  const [rows] = await db.execute(
    `SELECT a.id, a.type, a.status, u.name as userName, u.username,
            DATE_FORMAT(a.start_date, '%Y-%m-%d') as startDate,
            DATE_FORMAT(a.end_date, '%Y-%m-%d') as endDate,
            a.reason,
            DATE_FORMAT(a.created_at, '%Y-%m-%d %H:%i:%s') as createdAt
     FROM approval_requests a
     JOIN users u ON a.user_id = u.id
     WHERE a.status = ?${scope.sql}
     ORDER BY a.created_at DESC
     LIMIT 30`,
    [status, ...scope.params]
  );

  return {
    type: 'table',
    title: status === 'pending' ? '待处理审批' : '审批记录',
    message: `当前找到 ${rows.length} 条${status === 'pending' ? '待处理' : status}审批。`,
    columns: [
      { prop: 'userName', label: '申请人' },
      { prop: 'type', label: '类型' },
      { prop: 'startDate', label: '开始' },
      { prop: 'endDate', label: '结束' },
      { prop: 'reason', label: '原因' },
      { prop: 'createdAt', label: '提交时间' },
    ],
    rows,
  };
}

async function createPendingAction({ actor, conversationId, actionType, title, payload }) {
  const db = getPool();
  const [result] = await db.execute(
    `INSERT INTO ai_action_requests (conversation_id, user_id, action_type, title, payload, status)
     VALUES (?, ?, ?, ?, ?, 'pending')`,
    [conversationId, actor.id, actionType, title, toJson(payload)]
  );
  return {
    id: result.insertId,
    type: actionType,
    title,
    payload,
    status: 'pending',
  };
}

async function createReportAction(actor, conversationId, context = {}, message = '') {
  const range = parseDateRange(message, context);
  const action = await createPendingAction({
    actor,
    conversationId,
    actionType: 'export_attendance_report',
    title: `导出${range.label}考勤报表`,
    payload: { range },
  });

  return {
    type: 'action',
    title: action.title,
    message: '我已经准备好导出条件。确认后会生成可下载的考勤报表链接。',
    action,
  };
}

async function createNotificationAction(actor, conversationId, context = {}, message = '') {
  if (!permissions.canManage(actor)) {
    return {
      type: 'summary',
      title: '发送通知',
      message: '当前账号没有发送系统通知的权限。',
      cards: [],
    };
  }

  const lastEmployee = context.lastEmployee || null;
  const text = String(message);
  const content = text
    .replace(/^(请|帮我)?(给|向)?(所有人|全部员工|大家|他|她|该员工)?(发送|发一条|通知)/, '')
    .replace(/^通知(他|她|该员工)?/, '')
    .replace(/^(他|她|该员工)/, '')
    .trim() || '请关注今日考勤与项目安排。';

  const target = /他|她|该员工/.test(text) && lastEmployee
    ? { type: 'user', userId: lastEmployee.id, userName: lastEmployee.name }
    : { type: 'visible_active_users' };

  const action = await createPendingAction({
    actor,
    conversationId,
    actionType: 'send_notification',
    title: target.type === 'user' ? `通知 ${target.userName}` : '发送系统通知',
    payload: {
      title: context.title || 'AI 助手通知',
      content,
      target: target.type,
      userId: target.userId || null,
      userName: target.userName || null,
      type: 'system',
    },
  });

  return {
    type: 'action',
    title: action.title,
    message: target.type === 'user'
      ? `我会把这条通知发给 ${target.userName}，确认后再发送。`
      : '这是一项会触达员工的操作，需要你确认后再发送。',
    action,
  };
}

function extractProjectName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:新增|创建|添加|新建)\s*(?:一个)?(?:项目)?\s*([一-龥A-Za-z0-9_\-]{2,40})?/);
  return stripTrailingParticle(match?.[1] || '');
}

async function createProjectAction(actor, conversationId, context = {}, message = '') {
  if (!permissions.canManage(actor)) {
    return {
      type: 'clarification',
      title: '新增项目',
      message: '当前账号没有新增项目的权限。',
      prompts: [],
    };
  }

  const projectName = context.projectName || extractProjectName(message);
  if (!projectName) {
    return {
      type: 'clarification',
      title: '新增项目',
      message: '可以新增项目，不过我还需要几个关键信息。',
      prompts: ['项目名称', '项目地址或围栏中心位置', '围栏半径（默认 500 米）'],
    };
  }

  const action = await createPendingAction({
    actor,
    conversationId,
    actionType: 'create_project',
    title: `新增项目：${projectName}`,
    payload: {
      name: projectName,
      address: context.address || '',
      radius: Number(context.radius || 500),
      description: context.description || '由 AI 助手创建',
    },
  });

  return {
    type: 'action',
    title: action.title,
    message: `我已准备创建项目「${projectName}」。如果地址和围栏信息还不完整，建议先补充后再确认。`,
    action,
  };
}

function extractDateWord(message) {
  const now = new Date();
  if (/明天/.test(message)) {
    return formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1));
  }
  if (/后天/.test(message)) {
    return formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2));
  }
  const match = String(message).match(/(\d{4}-\d{1,2}-\d{1,2})/);
  if (match) return match[1];
  return formatDate(now);
}

async function createScheduleAction(actor, conversationId, context = {}, message = '') {
  if (!permissions.canManage(actor)) {
    return {
      type: 'summary',
      title: '创建排班',
      message: '当前账号没有创建排班的权限。',
      cards: [],
    };
  }

  const db = getPool();
  const userKeyword = context.employeeName || extractScheduleUserName(message);
  const target = await findVisibleUser(actor, userKeyword);
  const shiftKeyword = context.shiftName || extractShiftKeyword(message);
  const [shiftRows] = shiftKeyword
    ? await db.execute(
      `SELECT id, name, start_time, end_time
       FROM shifts
       WHERE status = 1 AND name LIKE ?
       ORDER BY sort_order ASC, id ASC
       LIMIT 1`,
      [`%${shiftKeyword}%`]
    )
    : await db.execute(
      `SELECT id, name, start_time, end_time
       FROM shifts
       WHERE status = 1
       ORDER BY sort_order ASC, id ASC
       LIMIT 1`
    );
  const shift = shiftRows[0];

  if (!target || !shift) {
    return {
      type: 'summary',
      title: '创建排班',
      message: '还缺少可执行的排班信息。请说明员工姓名、日期和班次，例如“把张三明天安排白班”。',
      cards: [],
    };
  }

  const date = context.date || extractDateWord(message);
  const action = await createPendingAction({
    actor,
    conversationId,
    actionType: 'create_schedule',
    title: `为 ${target.name || target.username} 创建排班`,
    payload: {
      userId: target.id,
      userName: target.name || target.username,
      date,
      shiftId: shift.id,
      shiftName: shift.name,
    },
  });

  return {
    type: 'action',
    title: action.title,
    message: `准备将 ${target.name || target.username} 在 ${date} 安排为 ${shift.name}。确认后写入排班表。`,
    action,
  };
}

async function executeConfirmedAction(actor, actionId, ipAddress) {
  const db = getPool();
  const [rows] = await db.execute(
    `SELECT id, conversation_id, user_id, action_type, title, payload, status
     FROM ai_action_requests
     WHERE id = ? AND user_id = ?
     LIMIT 1`,
    [Number(actionId), actor.id]
  );

  if (rows.length === 0) {
    const err = new Error('操作不存在或无权限');
    err.status = 404;
    throw err;
  }
  const action = rows[0];
  if (action.status !== 'pending') {
    const err = new Error('该操作已处理，不能重复确认');
    err.status = 400;
    throw err;
  }

  const payload = fromJson(action.payload);
  let result;

  if (action.action_type === 'send_notification') {
    if (!permissions.canManage(actor)) {
      const err = new Error('没有发送通知权限');
      err.status = 403;
      throw err;
    }
    if (payload.target === 'user' && payload.userId) {
      const target = await findVisibleUser(actor, payload.userName || '');
      if (!target || Number(target.id) !== Number(payload.userId)) {
        const err = new Error('通知对象不存在或无权限');
        err.status = 403;
        throw err;
      }
      await notificationService.createNotification({
        user_id: payload.userId,
        title: payload.title || 'AI 助手通知',
        content: payload.content,
        type: payload.type || 'system',
      });
      result = { count: 1, message: `已向 ${payload.userName || '该员工'}发送通知` };
    } else {
      const scope = permissions.scopeUserWhere(actor, 'u');
      const [userRows] = await db.execute(
        `SELECT u.id FROM users u WHERE u.status = 1${scope.sql}`,
        scope.params
      );
      const userIds = userRows.map((row) => row.id);
      const count = await notificationService.createNotificationForUsers(userIds, {
        title: payload.title || 'AI 助手通知',
        content: payload.content,
        type: payload.type || 'system',
      });
      result = { count, message: `已向 ${count} 位员工发送通知` };
    }
  } else if (action.action_type === 'create_schedule') {
    if (!permissions.canManage(actor)) {
      const err = new Error('没有创建排班权限');
      err.status = 403;
      throw err;
    }
    const target = await findVisibleUser(actor, payload.userName || '');
    if (!target || Number(target.id) !== Number(payload.userId)) {
      const err = new Error('排班员工不存在或无权限');
      err.status = 403;
      throw err;
    }
    await db.execute(
      `INSERT INTO user_schedules (user_id, date, shift_id, is_rest)
       VALUES (?, ?, ?, 0)
       ON DUPLICATE KEY UPDATE shift_id = VALUES(shift_id), is_rest = 0, updated_at = NOW()`,
      [payload.userId, payload.date, payload.shiftId]
    );
    result = {
      userId: payload.userId,
      userName: payload.userName,
      date: payload.date,
      shiftId: payload.shiftId,
      shiftName: payload.shiftName,
      message: '排班已创建或更新',
    };
  } else if (action.action_type === 'export_attendance_report') {
    const range = payload.range || {};
    const query = new URLSearchParams();
    if (range.start) query.set('date_start', range.start);
    if (range.end) query.set('date_end', range.end);
    result = {
      url: `/api/checkin/export?${query.toString()}`,
      message: '报表链接已生成',
    };
  } else if (action.action_type === 'create_project') {
    if (!permissions.canManage(actor)) {
      const err = new Error('没有新增项目权限');
      err.status = 403;
      throw err;
    }
    const [insertResult] = await db.execute(
      `INSERT INTO projects (name, address, radius, status, description)
       VALUES (?, ?, ?, 1, ?)`,
      [payload.name, payload.address || '', Number(payload.radius || 500), payload.description || '']
    );
    result = {
      id: insertResult.insertId,
      name: payload.name,
      message: `项目「${payload.name}」已创建`,
    };
  } else {
    const err = new Error('暂不支持该操作类型');
    err.status = 400;
    throw err;
  }

  await db.execute(
    `UPDATE ai_action_requests
     SET status = 'confirmed', result = ?, confirmed_at = NOW()
     WHERE id = ?`,
    [toJson(result), action.id]
  );
  await db.execute(
    `INSERT INTO ai_audit_logs (user_id, action_type, payload, result, ip_address)
     VALUES (?, ?, ?, ?, ?)`,
    [actor.id, action.action_type, toJson(payload), toJson(result), ipAddress || null]
  );

  return { ...action, payload, status: 'confirmed', result };
}

module.exports = {
  parseDateRange,
  getDashboardSummary,
  getAttendanceAnomalies,
  getProjectStats,
  getEmployeeAttendance,
  getApprovalSummary,
  createReportAction,
  createNotificationAction,
  createProjectAction,
  createScheduleAction,
  executeConfirmedAction,
};
