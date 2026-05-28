const jwt = require('jsonwebtoken');
const { getPool } = require('../models/db');
const config = require('../config');
const { successResponse, errorResponse } = require('../utils/helpers');

function generateRefreshToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username },
    config.jwt.refreshSecret,
    { expiresIn: config.jwt.refreshExpiresIn }
  );
}

function generateAccessToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username, role: user.role, name: user.name },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
}

function getRefreshExpiresAt() {
  const expiresIn = config.jwt.refreshExpiresIn;
  if (typeof expiresIn === 'string') {
    const match = expiresIn.match(/^(\d+)([dhms])$/);
    if (match) {
      const value = parseInt(match[1], 10);
      const unit = match[2];
      const now = Date.now();
      switch (unit) {
        case 'd':
          return new Date(now + value * 24 * 60 * 60 * 1000);
        case 'h':
          return new Date(now + value * 60 * 60 * 1000);
        case 'm':
          return new Date(now + value * 60 * 1000);
        case 's':
          return new Date(now + value * 1000);
        default:
          break;
      }
    }
  }

  if (typeof expiresIn === 'number') {
    return new Date(Date.now() + expiresIn * 1000);
  }

  return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
}

async function createSession(userId, refreshToken, deviceInfo, ipAddress, platform, deviceId) {
  const db = getPool();
  const expiresAt = getRefreshExpiresAt();

  const p = platform || 'unknown';
  await db.execute(
    'DELETE FROM sessions WHERE user_id = ? AND platform = ?',
    [userId, p]
  );

  await db.execute(
    'INSERT INTO sessions (user_id, refresh_token, device_info, ip_address, expires_at, platform, device_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [userId, refreshToken, deviceInfo || null, ipAddress || null, expiresAt, p, deviceId || null]
  );
}

async function refreshToken(req, res) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      return res.status(400).json(errorResponse('Refresh Token 不能为空', 400));
    }

    const db = getPool();
    const [sessions] = await db.execute(
      'SELECT s.*, u.id, u.username, u.name, u.role FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.refresh_token = ? AND s.expires_at > NOW()',
      [refresh_token]
    );

    if (sessions.length === 0) {
      return res.status(401).json(errorResponse('Refresh Token 无效或已过期', 401));
    }

    const session = sessions[0];
    
    try {
      jwt.verify(refresh_token, config.jwt.refreshSecret);
    } catch (err) {
      await db.execute('DELETE FROM sessions WHERE id = ?', [session.id]);
      return res.status(401).json(errorResponse('Refresh Token 无效或已过期', 401));
    }

    const newAccessToken = generateAccessToken(session);
    const newRefreshToken = generateRefreshToken(session);
    const expiresAt = getRefreshExpiresAt();

    await db.execute(
      'UPDATE sessions SET refresh_token = ?, expires_at = ?, updated_at = NOW() WHERE id = ?',
      [newRefreshToken, expiresAt, session.id]
    );

    res.json(successResponse({ 
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      expires_at: expiresAt
    }, 'Token 刷新成功'));
  } catch (err) {
    console.error('刷新 Token 失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function destroySession(req, res) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      return res.status(400).json(errorResponse('Refresh Token 不能为空', 400));
    }

    const db = getPool();
    await db.execute('DELETE FROM sessions WHERE refresh_token = ?', [refresh_token]);

    res.json(successResponse(null, '登出成功'));
  } catch (err) {
    console.error('销毁 Session 失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

async function destroyAllUserSessions(userId) {
  const db = getPool();
  await db.execute('DELETE FROM sessions WHERE user_id = ?', [userId]);
}

module.exports = {
  createSession,
  generateRefreshToken,
  generateAccessToken,
  refreshToken,
  destroySession,
  destroyAllUserSessions
};
