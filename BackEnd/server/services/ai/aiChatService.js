const { getPool } = require('../../models/db');
const aiClient = require('./aiClient');
const permissions = require('./aiPermissions');
const tools = require('./aiTools');

const SYSTEM_PROMPT = [
  '你是境图考勤系统的 AI 数据助理。',
  '你只能基于后端工具返回的数据回答，不编造员工、项目、审批或打卡记录。',
  '涉及新增排班、发送通知、导出报表等动作时，必须先要求管理员确认。',
  '你要自然承接上下文。用户说“他/她/该员工/继续/再看一下”时，优先参考最近会话对象和上一轮结果。',
  '回答要像可靠的运营助理：先给结论，再给关键依据和下一步建议。语气温和、简洁，不要机械地说“根据系统返回”。',
  '不要输出 Markdown 表格；可以使用短段落和项目符号。不要暴露 JSON 字段名。',
].join('\n');

function shortTitle(message) {
  const text = String(message || '新对话').replace(/\s+/g, ' ').trim();
  return text.length > 28 ? `${text.slice(0, 28)}...` : text || '新对话';
}

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

  const [result] = await db.execute(
    `INSERT INTO ai_conversations (user_id, title) VALUES (?, ?)`,
    [actor.id, shortTitle(message)]
  );
  return { id: result.insertId, title: shortTitle(message) };
}

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

function safeParseJson(value) {
  if (!value) return null;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

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

function isContinueText(message = '') {
  return /^(继续|接着|继续说|展开|详细点|再说说|然后呢|下一步)$/i.test(String(message).trim());
}

function detectIntent(message = '', context = {}, memory = {}) {
  const text = String(message);
  const page = context.page || '';

  if (isContinueText(text) && memory.lastResult) return 'continue';
  if (/新增项目|创建项目|新建项目|添加项目/.test(text)) return 'create_project';
  if (/导出|报表|Excel|excel|下载/.test(text)) return 'report';
  if (/发送|通知|广播|提醒/.test(text)) return 'notification';
  if (/排班|安排.*班|班次/.test(text)) return 'schedule';
  if (/审批|待办|请假|补卡|加班|外出申请/.test(text)) return 'approvals';
  if (/(他|她|该员工).*(考勤|打卡|记录|是否|正常)/.test(text) && memory.lastSubject?.type === 'employee') return 'employee';
  if (/异常|迟到|早退|围栏外|未打卡|缺勤/.test(text)) return 'anomalies';
  if (/项目|工地|外勤|工程/.test(text)) return 'projects';
  if (/员工|人员|个人|最近|考勤情况|打卡情况/.test(text)) return 'employee';

  if (page === 'checkin') return 'anomalies';
  if (page === 'projects' || page === 'location') return 'projects';
  if (page === 'schedules') return 'schedule';
  if (page === 'notifications') return 'notification';
  return 'summary';
}

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

async function chat({ user, message, context = {}, conversationId }) {
  if (!message || !String(message).trim()) {
    const err = new Error('消息不能为空');
    err.status = 400;
    throw err;
  }

  const actor = await permissions.loadActor(user);
  const conversation = await ensureConversation(actor, conversationId, message);
  const memory = await loadConversationMemory(conversation.id);
  const contextualContext = {
    ...context,
    lastEmployee: memory.lastSubject?.type === 'employee' ? memory.lastSubject : null,
    lastEmployeeName: memory.lastSubject?.type === 'employee' ? memory.lastSubject.name : '',
  };

  await saveMessage({
    conversationId: conversation.id,
    userId: actor.id,
    role: 'user',
    content: String(message).trim(),
    metadata: { context: contextualContext },
  });

  const intent = detectIntent(message, contextualContext, memory);
  const result = await runIntent({
    intent,
    actor,
    conversationId: conversation.id,
    context: contextualContext,
    message,
    memory,
  });
  const answer = await composeAnswer(message, result, memory.history);

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

async function getMessages(user, conversationId) {
  const actor = await permissions.loadActor(user);
  const db = getPool();
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

async function deleteConversation(user, conversationId) {
  const actor = await permissions.loadActor(user);
  const db = getPool();
  const [result] = await db.execute(
    `UPDATE ai_conversations SET deleted_at = NOW() WHERE id = ? AND user_id = ?`,
    [Number(conversationId), actor.id]
  );
  return result.affectedRows > 0;
}

async function confirmAction({ user, actionId, ipAddress }) {
  const actor = await permissions.loadActor(user);
  return tools.executeConfirmedAction(actor, actionId, ipAddress);
}

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
