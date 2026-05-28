/**
 * AI 模型 HTTP 客户端
 *
 * 职责：封装对 OpenAI 兼容 API 的调用（DeepSeek / 通义千问 等）。
 *
 * 核心流程：
 *   aiClient.summarizeWithModel({ system, user, data, history })
 *     → 把模板引擎查到的业务数据 + 对话历史 + 用户问题
 *       拼成 prompt 发给大模型
 *     → 大模型返回自然语言回答（"王经理查到了 3 条异常…"）
 *     → 如果模型不可用，走 fallback 兜底文案
 *
 * 配置项（.env 文件）：
 *   AI_API_KEY     — API Key
 *   AI_BASE_URL    — 接口地址（如 https://api.deepseek.com/v1）
 *   AI_MODEL       — 模型名（如 deepseek-v4-flash）
 *   AI_TIMEOUT_MS  — 超时时间（默认 30000ms）
 */

const axios = require('axios');
const config = require('../../config');

/**
 * 检查 AI 是否已正确配置
 */
function isEnabled() {
  return Boolean(config.ai.apiKey && config.ai.model);
}

/**
 * 构建 OpenAI 兼容的 /chat/completions 端点 URL
 */
function buildUrl() {
  return `${config.ai.baseUrl.replace(/\/$/, '')}/chat/completions`;
}

/**
 * 调用大模型将结构化数据转化为自然语言回答
 *
 * @param {Object} options
 * @param {string} options.system  — system prompt（定义 AI 人设）
 * @param {string} options.user    — 用户原始问题
 * @param {Object} options.data    — 业务工具返回的结构化数据（JSON）
 * @param {Array}  options.history — 最近 12 条对话历史
 * @returns {string|null} 自然语言回答，模型不可用时返回 null
 */
async function summarizeWithModel({ system, user, data, history = [] }) {
  if (!isEnabled()) return null;

  // 取最近 8 轮对话，转成"用户/助手"格式文本
  const historyText = history
    .slice(-8)
    .map((item) => `${item.role === 'user' ? '用户' : '助手'}：${item.content}`)
    .join('\n');

  const payload = {
    model: config.ai.model,
    temperature: 0.2,                             // 低温度 = 稳定、客观
    messages: [
      { role: 'system', content: system },
      {
        role: 'user',
        content: [
          historyText ? `最近会话：\n${historyText}` : '',
          `当前用户问题：${user}`,
          `业务数据 JSON：\n${JSON.stringify(data).slice(0, 14000)}`,  // 截断防止超 token
        ].filter(Boolean).join('\n\n'),
      },
    ],
  };

  const response = await axios.post(buildUrl(), payload, {
    timeout: config.ai.timeout,
    headers: {
      Authorization: `Bearer ${config.ai.apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  // OpenAI 兼容响应格式：choices[0].message.content
  return response.data?.choices?.[0]?.message?.content?.trim() || null;
}

module.exports = {
  isEnabled,
  summarizeWithModel,
};
