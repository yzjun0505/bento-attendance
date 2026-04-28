/**
 * JWT 鉴权中间件
 */
const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * 验证 Token
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ code: 401, message: '未登录或Token已过期' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ code: 401, message: 'Token无效或已过期' });
  }
}

/**
 * 验证管理员权限
 */
function adminOnly(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ code: 403, message: '无权限，需要管理员权限' });
  }
  next();
}

/**
 * 验证管理员或项目经理权限
 */
function managerOrAdmin(req, res, next) {
  if (req.user.role !== 'admin' && req.user.role !== 'manager') {
    return res.status(403).json({ code: 403, message: '无权限，需要管理员或项目经理权限' });
  }
  next();
}

module.exports = { authMiddleware, adminOnly, managerOrAdmin };
