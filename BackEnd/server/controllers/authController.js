/**
 * 认证控制器
 */
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getPool } = require('../models/db');
const config = require('../config');
const { successResponse, errorResponse } = require('../utils/helpers');
const openIMService = require('../services/openimService');
const { createSession, generateRefreshToken, generateAccessToken } = require('./sessionController');

/**
 * 登录
 * POST /api/auth/login
 */
async function login(req, res) {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json(errorResponse('用户名和密码不能为空', 400));
    }

    const db = getPool();
    const [rows] = await db.execute(
      'SELECT id, username, password, name, role, phone, avatar, status FROM users WHERE username = ?',
      [username]
    );

    if (rows.length === 0) {
      return res.status(401).json(errorResponse('用户名或密码错误', 401));
    }

    const user = rows[0];
    if (user.status === 0) {
      return res.status(403).json(errorResponse('账号已被禁用', 403));
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json(errorResponse('用户名或密码错误', 401));
    }

    const token = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);
    
    const deviceInfo = req.headers['user-agent'];
    const platform = req.headers['x-platform'] || 'unknown';
    const deviceId = req.headers['x-device-id'] || null;
    const ipAddress = req.ip || req.connection.remoteAddress;
    
    await createSession(user.id, refreshToken, deviceInfo, ipAddress, platform, deviceId);

    // --- OpenIM 异步处理流程 ---
    let imToken = null;
    console.log(`主登录完成，开始异步处理 OpenIM [用户ID: ${user.id}]`);

    // 我们可以尝试在短时间内同步获取，如果快就带上，如果不快就让前端之后补偿
    const imPromise = (async () => {
      try {
        const regResult = await openIMService.registerUser({
          userID: user.id,
          nickname: user.name || user.username,
          faceURL: user.avatar || '',
        });

        if (regResult.success) {
          const tokenResult = await openIMService.getUserToken(user.id, 1);
          if (tokenResult.success && tokenResult.data) {
            return tokenResult.data.token;
          }
        }
      } catch (err) {
        console.warn(`OpenIM 异步处理静默失败 [${user.id}]:`, err.message);
      }
      return null;
    })();

    // 设置一个较短的超时时间（例如 2s），如果 IM 响应快就直接返回，慢就让前端之后拿
    try {
      imToken = await Promise.race([
        imPromise,
        new Promise((resolve) => setTimeout(() => resolve(null), 2000))
      ]);
      if (imToken) {
        console.log(`OpenIM Token 同步获取成功 [${user.id}]`);
      } else {
        console.log(`OpenIM Token 处理中或已超时，将通过异步补偿完成 [${user.id}]`);
      }
    } catch (e) {
      imToken = null;
    }

    const reqHost = req.get('host') || 'localhost:3000';
    const imConfig = openIMService.getConfig(reqHost);

    const { password: _, ...userInfo } = user;
    res.json(successResponse({ 
      token: token,
      access_token: token,
      refresh_token: refreshToken,
      user: userInfo,
      imToken,
      imConfig: imConfig,
      imAsync: !imToken // 告诉前端是否需要后续补偿获取
    }, '登录成功'));
  } catch (err) {
    console.error('登录失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 注册
 * POST /api/auth/register
 */
async function register(req, res) {
  try {
    const { username, password, name, phone, role } = req.body;
    if (!username || !password) {
      return res.status(400).json(errorResponse('用户名和密码不能为空', 400));
    }

    const usernameRegex = /^[a-zA-Z0-9]+$/;
    if (!usernameRegex.test(username)) {
      return res.status(400).json(errorResponse('用户名只能包含英文字母和数字', 400));
    }

    const db = getPool();
    const [existing] = await db.execute('SELECT id FROM users WHERE username = ?', [username]);
    if (existing.length > 0) {
      return res.status(400).json(errorResponse('用户名已存在', 400));
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await db.execute(
      'INSERT INTO users (username, password, name, phone, role) VALUES (?, ?, ?, ?, ?)',
      [username, hashedPassword, name || '', phone || '', role || 'worker']
    );

    res.json(successResponse({ id: result.insertId }, '注册成功'));
  } catch (err) {
    console.error('注册失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取当前用户信息
 * GET /api/auth/profile
 */
async function getProfile(req, res) {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      'SELECT u.id, u.username, u.name, u.role, u.phone, u.avatar, u.status, u.project_id, p.name as project_name FROM users u LEFT JOIN projects p ON u.project_id = p.id WHERE u.id = ?',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    console.error('获取用户信息失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 修改密码
 * PUT /api/auth/password
 */
async function changePassword(req, res) {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) {
      return res.status(400).json(errorResponse('旧密码和新密码不能为空', 400));
    }

    const db = getPool();
    const [rows] = await db.execute('SELECT password FROM users WHERE id = ?', [req.user.id]);
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('用户不存在', 404));
    }

    const isMatch = await bcrypt.compare(oldPassword, rows[0].password);
    if (!isMatch) {
      return res.status(400).json(errorResponse('旧密码错误', 400));
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await db.execute('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, req.user.id]);

    res.json(successResponse(null, '密码修改成功'));
  } catch (err) {
    console.error('修改密码失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 获取 IM Token（用于登录后补偿获取）
 * GET /api/auth/im-token
 */
async function getIMToken(req, res) {
  try {
    const userID = req.user.id;
    console.log(`收到 IM Token 补偿请求 [用户ID: ${userID}]`);

    // 尝试获取用户 OpenIM 信息（确保已注册）
    await openIMService.registerUser({
      userID: userID,
      nickname: req.user.name || req.user.username,
      faceURL: req.user.avatar || '',
    });

    const tokenResult = await openIMService.getUserToken(userID, 1);
    if (tokenResult.success && tokenResult.data) {
      const reqHost = req.get('host') || 'localhost:3000';
      const imConfig = openIMService.getConfig(reqHost);
      
      return res.json(successResponse({
        imToken: tokenResult.data.token,
        imConfig: imConfig
      }, '获取 IM Token 成功'));
    }

    res.status(500).json(errorResponse('获取 IM Token 失败: ' + (tokenResult.message || '未知错误')));
  } catch (err) {
    console.error('获取 IM Token 异常:', err);
    res.status(500).json(errorResponse('服务器内部错误'));
  }
}

module.exports = { login, register, getProfile, changePassword, getIMToken };
