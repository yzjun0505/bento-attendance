/**
 * AI 对话管理服务
 *
 * 职责：AI 助手的”大脑”——管理对话会话、意图识别、数据查询、Answer 生成。
 *
 * 一条消息的完整处理链路：
 *   chat()
 *     → ensureConversation()     保存/复用会话
 *     → loadConversationMemory() 加载最近 12 条历史
 *     → detectIntent()           正则匹配 → 意图类型
 *     → runIntent()              路由到 aiTools 的对应函数（查数据库）
 *     → composeAnswer()          调用大模型把数据转成自然语言
 *     → saveMessage()            写入 ai_messages
 *     → 返回 { conversationId, message, intent, result }
 *
 * 关键设计：
 *   - “模板引擎”模式：数据库查询在 Node 侧完成，业务数据不暴露 SQL
 *   - fallbackAnswer()：AI 模型不可用时，用预置文案兜底
 *   - continue 意图：用户说”继续”，直接复用上一轮结果，不再重复查询
 */

const { getPool } = require('../../models/db');
const aiClient = require('./aiClient');
const permissions = require('./aiPermissions');
const tools = require('./aiTools');

// ============================================================
// System Prompt — 定义 AI 人设
// ============================================================

const SYSTEM_PROMPT = [
  '你是境图项目协同管理平台的 AI 数据助理。',
  '你只能基于后端工具返回的数据回答，不编造员工、项目、审批或打卡记录。',
  '防伪码、水印码、打卡照片真伪、轨迹、路线、总里程都属于本系统业务范围；必须调用对应工具查询，不能说不属于业务范围。',
  '涉及新增排班、发送通知、导出报表等动作时，必须先要求管理员确认。',
  '你要自然承接上下文。用户说”他/她/该员工/继续/再看一下”时，优先参考最近会话对象和上一轮结果。',
  '回答要像可靠的运营助理：先给结论，再给关键依据和下一步建议。语气温和、简洁，不要机械地说”根据系统返回”。',
  '不要输出 Markdown 表格；可以使用短段落和项目符号。不要暴露 JSON 字段名。',
].join('\n');

// ============================================================
// 会话管理
// ============================================================

/**
 * 截取前 28 字符作为短标题
 */
function shortTitle(message) {
  const text = String(message || '新对话').replace(/\s+/g, ' ').trim();
  return text.length > 28 ? `${text.slice(0, 28)}...` : text || '新对话';
}

/**
 * 确保会话存在：有 conversationId 则复用，没有则新建。
 * 同时校验会话归属（user_id = actor.id），防止越权访问他人会话。
 */
async function ensureConversation(actor, conversationId, message) {
  const db = getPool();
  if (conversationId) {
    const [rows] = await db.execute(
      `SELECT id, title
       FROM ai_conversations
       WHERE id = ? AND user_id = ? AND deleted_at IS NULL
       LIMIT 1`,
      [Number(conversationId), actor.id]
    );
    if (rows.length > 0) return rows[0];
  }

  // 新建会话，标题取用户第一条消息的前 28 字
  const [result] = await db.execute(
    `INSERT INTO ai_conversations (user_id, title) VALUES (?, ?)`,
    [actor.id, shortTitle(message)]
  );
  return { id: result.insertId, title: shortTitle(message) };
}

/**
 * 保存一条消息到 ai_messages 表，同时更新会话的 updated_at
 */
async function saveMessage({ conversationId, userId, role, content, metadata }) {
  const db = getPool();
  await db.execute(
    `INSERT INTO ai_messages (conversation_id, user_id, role, content, metadata)
     VALUES (?, ?, ?, ?, ?)`,
    [conversationId, userId, role, content || '', metadata ? JSON.stringify(metadata) : null]
  );
  await db.execute(
    `UPDATE ai_conversations SET updated_at = NOW() WHERE id = ?`,
    [conversationId]
  );
}

// ============================================================
// 上下文记忆
// ============================================================

/**
 * 安全 JSON 解析（容错空值/已是对象/解析失败）
 */
function safeParseJson(value) {
  if (!value) return null;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

/**
 * 加载会话记忆
 *
 * 从 ai_messages 取最近 12 条消息（倒序取再反转回正序）。
 * 额外提取：
 *   history      — 对话历史文本（供大模型做上下文）
 *   lastIntent   — 上一轮的意图
 *   lastResult   — 上一轮的业务数据（供 continue 意图复用）
 *   lastSubject  — 上一轮涉及的对象（如某员工，供”他/她”指代）
 */
async function loadConversationMemory(conversationId) {
  const db = getPool();
  const [rows] = await db.execute(
    `SELECT role, content, metadata
     FROM ai_messages
     WHERE conversation_id = ?
     ORDER BY created_at DESC, id DESC
     LIMIT 12`,
    [Number(conversationId)]
  );

  const chronological = rows.reverse().map((row) => ({
    role: row.role,
    content: row.content,
    metadata: safeParseJson(row.metadata),
  }));

  // 找到最近一条 assistant 消息的 result 数据
  const assistantMessages = chronological
    .filter((row) => row.role === 'assistant' && row.metadata?.result)
    .reverse();
  const lastAssistant = assistantMessages[0] || null;
  const lastResult = lastAssistant?.metadata?.result || null;
  const lastSubject = lastResult?.subject || null;

  return {
    history: chronological.map((row) => ({ role: row.role, content: row.content })),
    lastIntent: lastAssistant?.metadata?.intent || null,
    lastResult,
    lastSubject,
  };
}

// ============================================================
// 意图识别
// ============================================================

/**
 * 判断是否是”继续”类指令
 */
function isContinueText(message = '') {
  return /^(继续|接着|继续说|展开|详细点|再说说|然后呢|下一步)$/i.test(String(message).trim());
}

/**
 * 意图识别引擎
 *
 * 纯正则匹配，不依赖大模型（节省一次 API 调用）。
 * 优先级从上到下：
 *   1. continue  — 复用上一轮结果
 *   2. watermark — 防伪码查询
 *   3. track     — 轨迹/里程
 *   4. create_*  — 新增/导出/通知/排班（需确认的操作）
 *   5. approvals — 审批
 *   6. employee  — 员工考勤（含”他/她”指代）
 *   7. anomalies — 异常打卡
 *   8. projects  — 项目统计
 *   9. fallback  — summary（仪表盘摘要）
 *
 * @param {string} message — 用户输入文本
 * @param {Object} context — { page, lastEmployee, ... }
 * @param {Object} memory  — { lastResult, lastSubject }
 * @returns {string} intent — 意图码
 */
function detectIntent(message = '', context = {}, memory = {}) {
  const text = String(message);
  const page = context.page || '';

  if (isContinueText(text) && memory.lastResult) return 'continue';
  if (/防伪码|水印码|验证码|真伪|查.*出处|出自哪里|哪里来的|对应.*打卡|[A-Fa-f0-9][A-Fa-f0-9\-\s]{11,}[A-Fa-f0-9]/.test(text)) return 'watermark';
  if (/轨迹|路线|位置回放|走了多少|总里程|路程|轨迹点/.test(text)) return 'track';
  if (/新增项目|创建项目|新建项目|添加项目/.test(text)) return 'create_project';
  if (/导出|报表|Excel|excel|下载/.test(text)) return 'report';
  if (/发送|通知|广播|提醒/.test(text)) return 'notification';
  if (/排班|安排.*班|班次/.test(text)) return 'schedule';
  if (/审批|待办|请假|补卡|加班|外出申请/.test(text)) return 'approvals';
  if (/(他|她|该员工).*(考勤|打卡|记录|是否|正常)/.test(text) && memory.lastSubject?.type === 'employee') return 'employee';
  if (/异常|迟到|早退|围栏外|未打卡|缺勤/.test(text)) return 'anomalies';
  if (/项目|工地|外勤|工程/.test(text)) return 'projects';
  if (/员工|人员|个人|最近|考勤情况|打卡情况/.test(text)) return 'employee';

  // 根据当前页面做上下文感知的意图推断
  if (page === 'checkin') return 'anomalies';
  if (page === 'projects' || page === 'location') return 'projects';
  if (page === 'schedules') return 'schedule';
  if (page === 'notifications') return 'notification';
  return 'summary';
}

/**
 * 意图路由——把意图码分发到 aiTools 的对应函数
 *
 * 返回的 result 对象统一包含 type 字段：
 *   'summary'   — 摘要卡（cards 数组）
 *   'table'     — 表格数据（columns + rows）
 *   'chart'     — 图表数据（含 chart 字段）
 *   'action'    — 需要二次确认的操作
 *   'clarification' — 信息不足，追问用户
 */
async function runIntent({ intent, actor, conversationId, context, message, memory }) {
  switch (intent) {
    case 'continue':
      return {
        ...memory.lastResult,
        continued: true,
        message: memory.lastResult?.message || '我接着上一轮结果继续说明。',
      };
    case 'create_project':
      return tools.createProjectAction(actor, conversationId, context, message);
    case 'report':
      return tools.createReportAction(actor, conversationId, context, message);
    case 'notification':
      return tools.createNotificationAction(actor, conversationId, context, message);
    case 'schedule':
      return tools.createScheduleAction(actor, conversationId, context, message);
    case 'watermark':
      return tools.getWatermarkCodeLookup(actor, context, message);
    case 'track':
      return tools.getTrackSummary(actor, context, message);
    case 'approvals':
      return tools.getApprovalSummary(actor, context, message);
    case 'anomalies':
      return tools.getAttendanceAnomalies(actor, context, message);
    case 'projects':
      return tools.getProjectStats(actor, context, message);
    case 'employee':
      return tools.getEmployeeAttendance(actor, context, message);
    case 'summary':
    default:
      return tools.getDashboardSummary(actor, context, message);
  }
}

// ============================================================
// Answer 生成
// ============================================================

/**
 * 兜底回答——大模型不可用时的预置文案
 *
 * 三种情况的处理：
 *   clarification → 信息不足，追问用户
 *   action        → 告知用户需要确认
 *   table (空)    → 提示无数据
 *   其他          → 直接用 result.message
 */
function fallbackAnswer(result) {
  if (result.type === 'clarification') {
    const prompts = result.prompts?.length ? `\n\n请补充：\n${result.prompts.map((item) => `- ${item}`).join('\n')}` : '';
    return `${result.message || '我还需要一点信息才能继续。'}${prompts}`;
  }
  if (result.type === 'action') return result.message || '我已准备好这项操作，请确认后执行。';
  if (result.type === 'table' && result.rows?.length === 0) {
    return `${result.title || '查询结果'}没有查到匹配记录。你可以换个时间范围、员工姓名或项目再试。`;
  }
  return result.message || '我已经按当前权限查到了相关数据。';
}

/**
 * 最终 Answer 生成
 *
 * 优先调用大模型做润色（把结构化数据转成自然语言）。
 * 大模型不可用时走 fallbackAnswer() 兜底。
 *
 * @param {string} message — 用户原始问题
 * @param {Object} result  — runIntent() 返回的业务数据
 * @param {Array}  history — 对话历史
 * @returns {string} 给用户展示的最终回答
 */
async function composeAnswer(message, result, history) {
  const fallback = fallbackAnswer(result);
  if (result.type === 'action') return fallback;
  if (result.type === 'clarification') return fallback;

  try {
    const aiText = await aiClient.summarizeWithModel({
      system: SYSTEM_PROMPT,
      user: message,
      data: result,
      history,
    });
    return aiText || fallback;
  } catch (_) {
    return fallback;
  }
}

// ============================================================
// 主入口：chat()
// ============================================================

/**
 * AI 对话主函数
 *
 * 完整处理一条用户消息，返回 AI 回答 + 会话信息。
 *
 * @param {Object}   user             — 当前用户（req.user）
 * @param {string}   message          — 用户输入文本
 * @param {Object}   context          — { page?, filters?, ... } 上下文
 * @param {number?}  conversationId   — 已有会话 ID（可选，新对话则为空）
 * @returns {{ conversationId, title, message, intent, aiModelEnabled, result }}
 */
async function chat({ user, message, context = {}, conversationId }) {
  if (!message || !String(message).trim()) {
    const err = new Error('消息不能为空');
    err.status = 400;
    throw err;
  }

  const actor = await permissions.loadActor(user);
  const conversation = await ensureConversation(actor, conversationId, message);
  const memory = await loadConversationMemory(conversation.id);

  // 把上一轮的 subject 注入上下文（用于”他/她”指代解析）
  const contextualContext = {
    ...context,
    lastEmployee: memory.lastSubject?.type === 'employee' ? memory.lastSubject : null,
    lastEmployeeName: memory.lastSubject?.type === 'employee' ? memory.lastSubject.name : '',
  };

  // Step 1: 保存用户消息
  await saveMessage({
    conversationId: conversation.id,
    userId: actor.id,
    role: 'user',
    content: String(message).trim(),
    metadata: { context: contextualContext },
  });

  // Step 2: 意图识别 → 执行数据查询
  const intent = detectIntent(message, contextualContext, memory);
  const result = await runIntent({
    intent,
    actor,
    conversationId: conversation.id,
    context: contextualContext,
    message,
    memory,
  });

  // Step 3: 生成回答（大模型润色 / fallback 兜底）
  const answer = await composeAnswer(message, result, memory.history);

  // Step 4: 保存 AI 回答
  await saveMessage({
    conversationId: conversation.id,
    userId: actor.id,
    role: 'assistant',
    content: answer,
    metadata: { intent, result, aiModelEnabled: aiClient.isEnabled() },
  });

  return {
    conversationId: conversation.id,
    title: conversation.title,
    message: answer,
    intent,
    aiModelEnabled: aiClient.isEnabled(),
    result,
  };
}

/**
 * 列出当前用户的所有会话（最近 50 条）
 */
async function listConversations(user) {
  const actor = await permissions.loadActor(user);
  const db = getPool();
  const [rows] = await db.execute(
    `SELECT id, title, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as createdAt,
            DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') as updatedAt
     FROM ai_conversations
     WHERE user_id = ? AND deleted_at IS NULL
     ORDER BY updated_at DESC
     LIMIT 50`,
    [actor.id]
  );
  return rows;
}

/**
 * 获取指定会话的完整消息记录（按时间正序）
 */
async function getMessages(user, conversationId) {
  const actor = await permissions.loadActor(user);
  const db = getPool();
  // 校验会话归属
  const [ownerRows] = await db.execute(
    `SELECT id FROM ai_conversations WHERE id = ? AND user_id = ? AND deleted_at IS NULL LIMIT 1`,
    [Number(conversationId), actor.id]
  );
  if (ownerRows.length === 0) {
    const err = new Error('会话不存在或无权限');
    err.status = 404;
    throw err;
  }

  const [rows] = await db.execute(
    `SELECT id, role, content, metadata, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as createdAt
     FROM ai_messages
     WHERE conversation_id = ?
     ORDER BY created_at ASC, id ASC`,
    [Number(conversationId)]
  );
  return rows.map((row) => ({
    ...row,
    metadata: row.metadata && typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
  }));
}

/**
 * 软删除会话（设置 deleted_at）
 */
async function deleteConversation(user, conversationId) {
  const actor = await permissions.loadActor(user);
  const db = getPool();
  const [result] = await db.execute(
    `UPDATE ai_conversations SET deleted_at = NOW() WHERE id = ? AND user_id = ?`,
    [Number(conversationId), actor.id]
  );
  return result.affectedRows > 0;
}

/**
 * 确认执行待确认操作（confirm action）
 *
 * AI 建议的”操作”（如发通知、建项目、排班）
 * 需要用户二次确认后才真正执行。
 * 确认后写入 ai_audit_logs 审计日志。
 */
async function confirmAction({ user, actionId, ipAddress }) {
  const actor = await permissions.loadActor(user);
  return tools.executeConfirmedAction(actor, actionId, ipAddress);
}

/**
 * 生成推荐问题（根据当前页面）
 */
function suggestions(context = {}) {
  const page = context.page || '';
  if (page === 'checkin') {
    return ['今天有哪些异常打卡？', '本周迟到最多的是谁？', '导出本月考勤报表'];
  }
  if (page === 'projects' || page === 'location') {
    return ['本周项目外勤打卡统计', '哪些项目围栏外打卡最多？', '总结今天现场出勤情况'];
  }
  if (page === 'schedules') {
    return ['帮我看今天排班情况', '把张三明天安排白班', '本周有哪些人未排班？'];
  }
  if (page === 'notifications') {
    return ['发送通知请大家及时打卡', '今天有哪些待处理提醒？', '生成一条考勤提醒文案'];
  }
  return ['今天管理摘要', '本周异常打卡统计', '有哪些待审批申请？', '项目外勤打卡排行'];
}

module.exports = {
  chat,
  listConversations,
  getMessages,
  deleteConversation,
  confirmAction,
  suggestions,
};
