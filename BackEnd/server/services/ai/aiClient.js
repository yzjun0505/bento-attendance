const axios = require('axios');
const config = require('../../config');

function isEnabled() {
  return Boolean(config.ai.apiKey && config.ai.model);
}

function buildUrl() {
  return `${config.ai.baseUrl.replace(/\/$/, '')}/chat/completions`;
}

async function summarizeWithModel({ system, user, data, history = [] }) {
  if (!isEnabled()) return null;

  const historyText = history
    .slice(-8)
    .map((item) => `${item.role === 'user' ? '用户' : '助手'}：${item.content}`)
    .join('\n');

  const payload = {
    model: config.ai.model,
    temperature: 0.2,
    messages: [
      { role: 'system', content: system },
      {
        role: 'user',
        content: [
          historyText ? `最近会话：\n${historyText}` : '',
          `当前用户问题：${user}`,
          `业务数据 JSON：\n${JSON.stringify(data).slice(0, 14000)}`,
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

  return response.data?.choices?.[0]?.message?.content?.trim() || null;
}

module.exports = {
  isEnabled,
  summarizeWithModel,
};
