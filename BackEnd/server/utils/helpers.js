/**
 * 工具函数
 */

/**
 * 统一响应格式
 */
function successResponse(data = null, message = '操作成功') {
  return { code: 200, message, data };
}

function errorResponse(message = '操作失败', code = 500) {
  return { code, message, data: null };
}

/**
 * 分页参数解析
 */
function parsePagination(query) {
  const page = Math.max(1, parseInt(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(query.pageSize) || 20));
  const offset = (page - 1) * pageSize;
  return { page, pageSize, offset };
}

/**
 * 获取当天日期范围（本地时间，避免 UTC 偏移）
 */
function getTodayRange() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0);
  return { start, end };
}

module.exports = { successResponse, errorResponse, parsePagination, getTodayRange };
