/**
 * 境图项目协同管理平台 - 后端服务入口
 */
require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const { initDatabase, getPool } = require('./models/db');
const { connectMongo, mongoHealth } = require('./models/mongo');
const { startScheduler } = require('./services/attendanceAnalyzer');
const logger = require('./utils/logger');

// 路由
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const checkinRoutes = require('./routes/checkin');
const locationRoutes = require('./routes/location');
const projectRoutes = require('./routes/projects');
const deviceRoutes = require('./routes/devices');
const uploadRoutes = require('./routes/upload');
const watermarkRoutes = require('./routes/watermarks');
const notificationRoutes = require('./routes/notifications');
const dashboardRoutes = require('./routes/dashboard');
const attendanceGroupRoutes = require('./routes/attendanceGroups');
const checkinTypeRoutes = require('./routes/checkinTypes');
const shiftRoutes = require('./routes/shifts');
const scheduleRoutes = require('./routes/schedules');
const holidayRoutes = require('./routes/holidays');
const offlineCheckinRoutes = require('./routes/offlineCheckins');
const trackRoutes = require('./routes/tracks');
const taskNodeRoutes = require('./routes/taskNodes');
const progressRoutes = require('./routes/progress');

const approvalRoutes = require('./routes/approvals');
const sessionsRoutes = require('./routes/sessions');
const imRoutes = require('./routes/im');
const aiRoutes = require('./routes/ai');
const appVersionRoutes = require('./routes/appVersion');
const projectManagerRoutes = require('./routes/projectManagers');
const projectClientRoutes = require('./routes/projectClients');

const app = express();
app.set('trust proxy', 1);
const server = http.createServer(app);

// ========================
// 请求限流
// ========================
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  message: { code: 429, message: '请求过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Socket.IO
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  },
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket', 'polling']
});

// 将 io 实例挂到 app 上，供 controller 使用
app.set('io', io);

// ========================
// 中间件
// ========================
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/api/', apiLimiter);

// 静态文件 - Web管理端
app.use(express.static(path.join(__dirname, '../dist')));

// 文件上传目录
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 健康检查和版本检查需要保持公开，移动端未登录时也会调用。
app.get('/api/health', async (req, res) => {
  // 注意：保持 HTTP 200，避免影响已有探活；通过 code/services 字段反映依赖状态
  const services = {
    mysql: { ok: true },
    mongo: { enabled: false, ok: true },
  };

  try {
    await getPool().query('SELECT 1');
    services.mysql.ok = true;
  } catch (err) {
    services.mysql.ok = false;
    services.mysql.error = err.message;
    logger.error('MySQL 健康检查失败', { error: err.message });
  }

  try {
    services.mongo = await mongoHealth();
  } catch (err) {
    services.mongo = { enabled: true, ok: false, error: err.message };
    logger.error('MongoDB 健康检查失败', { error: err.message });
  }

  const depsOk = services.mysql.ok && (!services.mongo.enabled || services.mongo.ok);
  res.json({
    code: depsOk ? 200 : 500,
    message: depsOk ? 'OK' : 'DEGRADED',
    services,
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/app', appVersionRoutes);

// ========================
// API 路由
// ========================
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/checkin', checkinRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/watermarks', watermarkRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/attendance-groups', attendanceGroupRoutes);
app.use('/api/checkin-types', checkinTypeRoutes);
app.use('/api/shifts', shiftRoutes);
app.use('/api/schedules', scheduleRoutes);
app.use('/api/holidays', holidayRoutes);
app.use('/api/offline-checkins', offlineCheckinRoutes);
app.use('/api/tracks', trackRoutes);
app.use('/api', taskNodeRoutes);
app.use('/api', progressRoutes);

app.use('/api/approvals', approvalRoutes);
app.use('/api/sessions', sessionsRoutes);
app.use('/api/im', imRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/project-managers', projectManagerRoutes);
app.use('/api/project-clients', projectClientRoutes);

// SPA 路由回退 — 所有非 API 请求返回 index.html（测试环境跳过）
if (process.env.NODE_ENV !== 'test') {
  app.get('*', (req, res) => {
    const distIndex = path.join(__dirname, '../dist/index.html');
    res.sendFile(distIndex, (err) => {
      if (err) {
        res.status(404).json({ code: 404, message: '页面不存在' });
      }
    });
  });
}

// ========================
// Socket.IO 事件
// ========================
const onlineUsers = new Map();

io.on('connection', (socket) => {
  logger.info(`Socket 连接: ${socket.id}`);

  // 用户上线
  socket.on('user:online', (data) => {
    onlineUsers.set(data.user_id, {
      socket_id: socket.id,
      user_id: data.user_id,
      user_name: data.user_name,
      connected_at: new Date().toISOString()
    });
    io.emit('online:count', onlineUsers.size);
    logger.info(`用户上线: ${data.user_name} (${data.user_id}), 在线人数: ${onlineUsers.size}`);
  });

  // 用户位置更新
  socket.on('location:report', (data) => {
    io.emit('location:update', {
      ...data,
      timestamp: new Date().toISOString()
    });
  });

  // 断开连接
  socket.on('disconnect', () => {
    for (const [userId, info] of onlineUsers) {
      if (info.socket_id === socket.id) {
        onlineUsers.delete(userId);
        logger.info(`用户离线: ${info.user_name} (${userId})`);
        break;
      }
    }
    io.emit('online:count', onlineUsers.size);
    logger.info(`Socket 断开: ${socket.id}, 在线人数: ${onlineUsers.size}`);
  });
});

// ========================
// 启动服务器
// ========================
async function start() {
  try {
    // 确保日志目录存在
    const fs = require('fs');
    const logsDir = path.join(__dirname, 'logs');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }

    // 初始化数据库
    await initDatabase();
    logger.info('数据库连接成功');

    // 初始化 MongoDB（Atlas）
    await connectMongo();

    // 启动考勤分析定时任务
    startScheduler();

    // 确保上传目录存在
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }

    server.listen(config.port, () => {
      logger.info(`服务已启动，端口: ${config.port}`);
      console.log(`
╔═══════════════════════════════════════════════════╗
║   境图项目协同管理平台 - 后端服务                  ║
║   服务地址: http://localhost:${config.port}              ║
║   API地址:  http://localhost:${config.port}/api           ║
║   管理端:   http://localhost:${config.port}               ║
╚═══════════════════════════════════════════════════╝
      `);
    });
  } catch (err) {
    logger.error('启动失败', { error: err.message, stack: err.stack });
    console.error('❌ 启动失败:', err);
    process.exit(1);
  }
}

// 导出 app 供测试使用
module.exports = { app, server, start };

// 非测试环境直接启动
if (process.env.NODE_ENV !== 'test') {
  start();
}
