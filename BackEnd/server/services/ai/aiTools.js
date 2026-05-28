/**
 * AI 可调用工具定义与执行
 *
 * 职责：AI 助手的"工具库"——实现所有可查询、可操作的后端能力。
 *
 * 架构说明：
 *   本模块是"模板引擎"模式的核心：所有数据查询都在 Node 侧完成，
 *   返回结构化结果给 aiChatService，再由大模型润色成自然语言。
 *   大模型不直接访问数据库（安全 + 权限可控）。
 *
 * 工具分为两类：
 *   【查询类】直接执行，立即返回数据：
 *     getDashboardSummary    — 仪表盘摘要（出勤/异常/审批 一览卡）
 *     getAttendanceAnomalies — 异常打卡列表
 *     getProjectStats        — 项目外勤统计 + 柱状图
 *     getEmployeeAttendance  — 单个员工考勤记录
 *     getWatermarkCodeLookup — 防伪码溯源
 *     getTrackSummary        — 轨迹回放 + 总里程
 *     getApprovalSummary     — 审批列表
 *
 *   【操作类】先写入 ai_action_requests 待确认表，用户确认后由 executeConfirmedAction() 执行：
 *     createReportAction       → export_attendance_report
 *     createNotificationAction → send_notification
 *     createProjectAction      → create_project
 *     createScheduleAction     → create_schedule
 *
 * 所有函数都通过 permissions.scopeXxxWhere() 做数据权限过滤。
 */

const { getPool } = require('../../models/db');
const notificationService = require('../notificationService');
const permissions = require('./aiPermissions');
const watermarkLookup = require('../watermarkLookupService');

// ============================================================
// 工具函数 — 日期/时间/格式化
// ============================================================

// 打卡类型常量：哪些 type 算"上班打卡"
const CHECKIN_IN_TYPES = ['in', 'clock_in'];
const CHECKIN_OUT_TYPES = ['out', 'clock_out'];

/** 补零 */
function pad(n) {
  return String(n).padStart(2, '0');
}

/** 格式化为 yyyy-MM-dd HH:mm:ss */
function formatDateTime(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

/** 格式化为 yyyy-MM-dd */
function formatDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/**
 * 从用户消息中解析时间范围
 *
 * 支持的自然语言：
 *   "今天" / "昨天" / "本周" / "本月" / "最近 N 天"
 *   也支持 context.filters 中显式传入的 date_start/date_end
 *
 * 默认：最近 7 天
 *
 * @returns {{ start, end, label }} — start/end 是格式化字符串，label 是中文标签
 */
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
    const days = Math.min(Math.max(Number(daysMatch[1]), 1), 90);              // 最多 90 天
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

  // 默认最近 7 天
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  return { start: formatDateTime(start), end: formatDateTime(end), label: '最近7天' };
}

/** JSON 序列化（容错） */
function toJson(value) {
  return JSON.stringify(value || {});
}

/** JSON 反序列化（容错） */
function fromJson(value) {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return {};
  }
}

/** 去除末尾的语气助词（"的呢吗吧啊呀"） */
function stripTrailingParticle(value = '') {
  return String(value).replace(/[的呢吗吧啊呀\s]+$/g, '').trim();
}

/**
 * 生成 ECharts 图表数据（供前端渲染柱状图等）
 */
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

// ============================================================
// 信息提取 — 从自然语言中提取结构化信息
// ============================================================

/**
 * 获取系统默认上班时间（用于判断"迟到"）
 */
async function getDefaultStartTime(db) {
  const [rows] = await db.execute(
    `SELECT work_start_time FROM attendance_groups WHERE status = 1 ORDER BY id LIMIT 1`
  );
  return rows[0]?.work_start_time || '09:00:00';
}

// ============================================================
// 查询工具 — 数据库查询，受权限控制
// ============================================================

/**
 * 📊 仪表盘摘要
 *
 * 返回一张"管理卡片"：可见员工数、出勤人数、异常数、活跃项目数、待审批数。
 * 这是 AI 助手默认调用的入口（用户问"今天概况"时）。
 */
async function getDashboardSummary(actor, context = {}, message = '') {
  const db = getPool();
  const range = parseDateRange(message, context);
  const userScope = permissions.scopeUserWhere(actor, 'u');         // 用户数据范围
  const checkinScope = permissions.scopeCheckinWhere(actor, 'c');   // 打卡数据范围
  const approvalScope = permissions.scopeUserWhere(actor, 'u');     // 审批数据范围

  // 可见员工数（受权限过滤）
  const [userRows] = await db.execute(
    `SELECT COUNT(*) as total FROM users u WHERE u.status = 1${userScope.sql}`,
    userScope.params
  );

  // 出勤人数（在时间范围内有上班打卡记录的独立用户数）
  const [attendanceRows] = await db.execute(
    `SELECT COUNT(DISTINCT c.user_id) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND c.type IN (?, ?)${checkinScope.sql}`,
    [range.start, range.end, ...CHECKIN_IN_TYPES, ...checkinScope.params]
  );

  // 异常打卡数（围栏外 OR 晚于默认上班时间）
  const [abnormalRows] = await db.execute(
    `SELECT COUNT(*) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND (c.is_outside = 1 OR (c.type IN (?, ?) AND TIME(c.created_at) > ?))${checkinScope.sql}`,
    [range.start, range.end, ...CHECKIN_IN_TYPES, await getDefaultStartTime(db), ...checkinScope.params]
  );

  // 活跃项目数（有打卡记录的独立项目数）
  const [projectRows] = await db.execute(
    `SELECT COUNT(DISTINCT c.project_id) as total
     FROM checkins c
     WHERE c.created_at >= ? AND c.created_at < ?
       AND c.project_id IS NOT NULL${checkinScope.sql}`,
    [range.start, range.end, ...checkinScope.params]
  );

  // 待审批数
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

/**
 * 🔴 异常打卡列表
 *
 * 异常定义：围栏外打卡（is_outside=1）OR 上班打卡时间晚于考勤组规定时间
 */
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

/**
 * 📂 项目外勤打卡统计
 *
 * 按项目聚合打卡数据（打卡次数/人数/围栏外次数），附带 ECharts 柱状图数据。
 */
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

// ============================================================
// 员工查找 — 根据姓名/关键词查找当前用户可见的员工
// ============================================================

/**
 * 在权限范围内查找员工
 *
 * 规则：
 *   keyword 为空 → 默认查当前用户自己
 *   keyword 有值 → 模糊匹配 name 或 username
 *   仅返回第一条匹配记录
 *
 * 权限：通过 scopeUserWhere 过滤
 */
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

// ============================================================
// NLP 信息提取 — 从自然语言文本中提取结构化字段
// ============================================================

/**
 * 从消息中提取可能的姓名（用于"张三最近考勤怎么样"）
 */
function extractPossibleName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:员工|人员|用户|工人)?\s*([一-龥A-Za-z0-9_]{2,20})\s*(?:的)?(?:最近|本周|本月|今天|考勤|打卡|记录|情况|迟到|是否|正常)/);
  if (!match) return '';
  const value = stripTrailingParticle(match[1]);
  if (/^(帮我|查询|看看|分析|总结|这个|今天|本周|本月|最近|员工)$/.test(value)) return '';
  return value;
}

/**
 * 从排班指令中提取员工名（"把张三明天安排白班" → "张三"）
 */
function extractScheduleUserName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:把|给|为)\s*([一-龥A-Za-z0-9_]{2,20})(?:今天|明天|后天|\d{4}-\d{1,2}-\d{1,2}|安排|排班|设为|上)/);
  return match ? match[1] : '';
}

/**
 * 从消息中提取班次关键词（"白班"/"早班"/"晚班"/"夜班"）
 */
function extractShiftKeyword(message) {
  const text = String(message || '');
  return ['白班', '早班', '晚班', '夜班'].find((name) => text.includes(name)) || '';
}

/**
 * 从消息中提取防伪码（匹配 8 位以上的十六进制字符）
 */
function extractWatermarkCode(message = '') {
  const candidates = String(message).match(/[A-Fa-f0-9][A-Fa-f0-9\-\s]{5,}[A-Fa-f0-9]/g) || [];
  return candidates
    .map(watermarkLookup.normalizeWatermarkCode)
    .find((code) => code.length >= 8) || '';
}

/**
 * 从消息中提取日期词（"明天"/"后天"/YYYY-MM-DD）
 */
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

// ============================================================
// 地理工具 — 距离计算 & 坐标校验
// ============================================================

/** 格式化距离：<1000m 显示米，>=1000m 显示公里 */
function formatDistanceMeters(meters) {
  const value = Number(meters || 0);
  if (value < 1000) return `${Math.round(value)} m`;
  return `${(value / 1000).toFixed(2)} km`;
}

/** 判断坐标是否合法（经度 -180~180，纬度 -90~90，且不为 0,0） */
function isValidCoordinate(point) {
  const lat = Number(point.latitude);
  const lng = Number(point.longitude);
  return Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0);
}

/** Haversine 公式 — 计算两点间球面距离（单位：米） */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;                                                    // 地球半径（米）
  const dLat = (Number(lat2) - Number(lat1)) * Math.PI / 180;
  const dLng = (Number(lng2) - Number(lng1)) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(Number(lat1) * Math.PI / 180) * Math.cos(Number(lat2) * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 计算轨迹总里程 — 逐点累加 Haversine 距离，过滤噪声跳点。
 * 数据来源：locations（GPS 实时上报）+ checkins（打卡位置）合并后按时间排序。
 */
function calculateTrackDistance(points) {
  let total = 0;
  for (let i = 1; i < points.length; i += 1) {
    const prev = points[i - 1];
    const point = points[i];
    const dist = calculateDistance(prev.latitude, prev.longitude, point.latitude, point.longitude);
    const seconds = Math.max((new Date(point.created_at) - new Date(prev.created_at)) / 1000, 0);
    const speed = seconds > 0 ? dist / seconds : 0;
    if (dist <= 50000 && (seconds === 0 || speed <= 45)) {
      total += dist;
    }
  }
  return Math.round(total);
}

// ============================================================
// 查询工具（续）
// ============================================================

/**
 * 🔍 防伪码溯源 — 根据防伪码查找对应的打卡记录或进度上报
 */
async function getWatermarkCodeLookup(actor, context = {}, message = '') {
  const db = getPool();
  const code = context.watermarkCode || extractWatermarkCode(message);
  if (!code) {
    return {
      type: 'clarification',
      title: '防伪码查询',
      message: '可以查询防伪码，请把完整防伪码发给我。',
      prompts: ['防伪码或水印码'],
    };
  }

  const checkinScope = permissions.scopeCheckinWhere(actor, 'c');
  const userScope = permissions.scopeUserWhere(actor, 'u');
  const lookup = await watermarkLookup.lookupWatermarkCode(db, code, {
    checkinScope: checkinScope.sql,
    checkinParams: checkinScope.params,
    userScope: userScope.sql,
    userParams: userScope.params,
  });

  if (!lookup.found) {
    return {
      type: 'summary',
      title: '防伪码查询',
      message: `没有查到防伪码 ${lookup.code} 对应的打卡、进度上报或预占记录。`,
      cards: [{ label: '查询结果', value: '未找到' }],
      rows: [],
    };
  }

  const row = lookup.data;
  const hasCheckin = lookup.kind === 'checkin';
  const hasProgress = lookup.kind === 'progress_report';
  return {
    type: 'table',
    title: '防伪码查询',
    message: hasCheckin
      ? `防伪码 ${row.watermark_code} 对应一条${row.project_name ? `「${row.project_name}」` : ''}打卡记录，状态为${row.code_status_text || '防伪码已使用'}。`
      : hasProgress
        ? `防伪码 ${row.watermark_code} 对应一条${row.project_name ? `「${row.project_name}」` : ''}项目进度上报，状态为${row.code_status_text || '防伪码已使用'}。`
      : `防伪码 ${row.watermark_code} 已生成但尚未绑定打卡记录，状态为${row.code_status_text}。`,
    cards: [
      { label: '防伪码', value: row.watermark_code },
      { label: '状态', value: row.code_status_text || row.code_status || '-' },
      { label: '打卡人', value: row.user_name || row.username || '-' },
      { label: '项目', value: row.project_name || '-' },
      { label: '业务类型', value: row.record_type_text || (hasCheckin ? '打卡记录' : '预占码') },
    ],
    columns: [
      { prop: 'watermark_code', label: '防伪码' },
      { prop: 'code_status_text', label: '状态' },
      { prop: 'record_type_text', label: '业务类型' },
      { prop: 'user_name', label: '打卡人' },
      { prop: 'project_name', label: '项目' },
      { prop: 'created_at', label: '时间' },
      { prop: 'address', label: '地点' },
    ],
    rows: [row],
  };
}

/**
 * 📍 轨迹回放 + 总里程统计
 * 合并 locations 和 checkins 两张表的坐标数据，按时间排序后计算总里程。
 */
async function getTrackSummary(actor, context = {}, message = '') {
  const db = getPool();
  const date = context.date || extractDateWord(message);
  const keyword = context.employeeName || context.lastEmployeeName || extractPossibleName(message);
  const target = await findVisibleUser(actor, keyword);
  if (!target) {
    return {
      type: 'summary',
      title: '轨迹查询',
      message: keyword ? `没有找到你有权限查看的员工：${keyword}。` : '没有找到可查看的员工。请补充员工姓名或先查询自己的轨迹。',
      cards: [],
    };
  }

  const [locationRows] = await db.execute(
    `SELECT id, latitude, longitude, accuracy, speed, address, created_at, 'location' as source
     FROM locations
     WHERE user_id = ? AND DATE(created_at) = ?
     ORDER BY created_at ASC`,
    [target.id, date]
  );
  const [checkinRows] = await db.execute(
    `SELECT id, latitude, longitude, address, type, photo, remark, created_at, 'checkin' as source
     FROM checkins
     WHERE user_id = ? AND DATE(created_at) = ? AND latitude IS NOT NULL AND longitude IS NOT NULL
     ORDER BY created_at ASC`,
    [target.id, date]
  );
  const points = [...locationRows, ...checkinRows]
    .filter(isValidCoordinate)
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const totalDistance = calculateTrackDistance(points);

  return {
    type: 'table',
    title: `${target.name || target.username} ${date}轨迹`,
    subject: {
      type: 'employee',
      id: target.id,
      name: target.name || target.username,
      username: target.username,
    },
    message: `${target.name || target.username} 在 ${date} 共有 ${points.length} 个轨迹点，总里程 ${formatDistanceMeters(totalDistance)}。`,
    cards: [
      { label: '员工', value: target.name || target.username },
      { label: '日期', value: date },
      { label: '轨迹点数', value: points.length },
      { label: '总里程', value: formatDistanceMeters(totalDistance) },
    ],
    columns: [
      { prop: 'created_at', label: '时间' },
      { prop: 'source', label: '来源' },
      { prop: 'address', label: '地点' },
      { prop: 'latitude', label: '纬度' },
      { prop: 'longitude', label: '经度' },
    ],
    rows: points.slice(0, 30),
  };
}

/**
 * 👤 单个员工考勤记录 — 返回时间范围内的所有打卡
 * 支持"他/她/该员工"指代（通过 context.lastEmployeeName）
 */
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

/**
 * 📋 审批列表 — 默认查 pending，可识别"已通过"/"拒绝"
 */
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

// ============================================================
// 操作工具 — 创建待确认操作 & 执行确认后的操作
// ============================================================

/**
 * 创建一条 pending 状态的 ai_action_request
 * AI 的"写操作"不会立即执行，而是先写入此表等用户确认。
 */
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

/**
 * 导出报表操作 — 写入 pending action，用户确认后生成下载链接
 */
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

/**
 * 发送通知操作 — 支持发给特定员工或所有可见员工
 */
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

/** 从消息中提取项目名 */
function extractProjectName(message) {
  const text = String(message || '').trim();
  const match = text.match(/(?:新增|创建|添加|新建)\s*(?:一个)?(?:项目)?\s*([一-龥A-Za-z0-9_\-]{2,40})?/);
  return stripTrailingParticle(match?.[1] || '');
}

/**
 * 新增项目操作 — 需要项目名称、地址、围栏半径
 */
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

/**
 * 排班操作 — 为用户指定日期安排班次
 */
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

/**
 * 🔐 执行确认后的操作
 *
 * 用户确认后，根据 action_type 真正执行：
 *   send_notification → 调用 notificationService 发送通知
 *   create_schedule   → 写入 user_schedules 表
 *   export_attendance_report → 生成下载链接
 *   create_project    → 写入 projects 表
 *
 * 执行完成后：更新 action status 为 confirmed + 写入 ai_audit_logs 审计日志
 */
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
  getWatermarkCodeLookup,
  getTrackSummary,
  getApprovalSummary,
  createReportAction,
  createNotificationAction,
  createProjectAction,
  createScheduleAction,
  executeConfirmedAction,
};
