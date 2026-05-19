/**
 * 数据库连接与初始化
 */
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const config = require('../config');
const logger = require('../utils/logger');

let pool = null;
let monitorInterval = null;

/**
 * 监控连接池状态
 */
function monitorPool() {
  if (!pool) return;

  const stats = {
    totalConnections: pool.pool ? pool.pool._allConnections.length : 0,
    freeConnections: pool.pool ? pool.pool._freeConnections.length : 0,
    waitingClients: pool.pool ? pool.pool._connectionQueue.length : 0,
    connectionLimit: pool.pool ? pool.pool.config.connectionLimit : 0,
    timestamp: new Date().toISOString()
  };

  logger.info('数据库连接池状态', stats);
}

/**
 * 获取数据库连接池
 */
function getPool() {
  if (!pool) {
      pool = mysql.createPool({
      ...config.db,
      // 不设 timezone，让 mysql2 自动检测 MySQL 服务器时区（本机 CST/北京时间）
      // 之前 timezone:'Z' 错误地告诉驱动数据库存的是 UTC，导致所有 DATETIME 偏移 8 小时
      dateStrings: true,
      // 连接超时配置（TiDB Cloud 公网连接需要更长的超时）
      connectTimeout: 30000,      // 30秒连接超时
      enableKeepAlive: true,      // 保持 TCP 连接
      keepAliveInitialDelay: 10000,
    });
    
    // 启动监控，每 30 秒打印一次连接池状态
    monitorInterval = setInterval(monitorPool, 30000);
    logger.info('数据库连接池监控已启动');
  }
  return pool;
}

/**
 * 关闭连接池和监控
 */
function closePool() {
  if (monitorInterval) {
    clearInterval(monitorInterval);
    monitorInterval = null;
  }
  if (pool) {
    pool.end();
    pool = null;
    logger.info('数据库连接池已关闭');
  }
}

/**
 * 初始化数据库（建表 + 默认管理员）
 */
async function initDatabase() {
  logger.info('正在初始化数据库连接...');
  // 先用不指定数据库的连接创建数据库
  // [修复] 必须包含 SSL 配置以支持 TiDB Cloud Serverless
  const tempConn = await mysql.createConnection({
    ...config.db,
    database: undefined, // 初始化建库时不需要指定数据库名
    dateStrings: true,
    connectTimeout: 30000,
  });

  logger.info(`正在检查/创建数据库: ${config.db.database}`);
  await tempConn.execute(
    `CREATE DATABASE IF NOT EXISTS \`${config.db.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
  );
  await tempConn.end();

  const db = getPool();

  // 创建用户表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      name VARCHAR(100) NOT NULL DEFAULT '',
      role ENUM('admin', 'manager', 'worker') NOT NULL DEFAULT 'worker',
      phone VARCHAR(20) DEFAULT '',
      project_id INT DEFAULT NULL,
      avatar VARCHAR(500) DEFAULT '',
      status TINYINT NOT NULL DEFAULT 1 COMMENT '1在职 0离职',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：为 users 表添加 email 字段（MySQL 不支持 ADD COLUMN IF NOT EXISTS）
  try {
    await db.execute(`
      ALTER TABLE users ADD COLUMN email VARCHAR(100) DEFAULT NULL COMMENT '邮箱'
    `);
    logger.info('已迁移 users 表：添加 email 字段');
  } catch (e) {
    if (e.code === 'ER_DUP_FIELDNAME') {
      // 字段已存在，无需操作
    } else {
      logger.error('迁移 users 表 email 字段失败', { error: e.message });
    }
  }

  // 创建项目表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS projects (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(200) NOT NULL,
      address VARCHAR(500) DEFAULT '',
      latitude DOUBLE DEFAULT NULL,
      longitude DOUBLE DEFAULT NULL,
      radius INT DEFAULT 500 COMMENT '打卡围栏半径(米)',
      status TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建打卡记录表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS checkins (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      project_id INT DEFAULT NULL,
      type VARCHAR(50) NOT NULL COMMENT '打卡类型(in/out/自定义)',
      latitude DOUBLE DEFAULT NULL,
      longitude DOUBLE DEFAULT NULL,
      address VARCHAR(500) DEFAULT '',
      photo VARCHAR(500) DEFAULT '',
      remark VARCHAR(500) DEFAULT '',
      is_outside TINYINT DEFAULT 0 COMMENT '1围栏外打卡 0正常',
      distance_to_fence DOUBLE DEFAULT NULL COMMENT '距离围栏距离(米)',
      outside_approval_status ENUM('none', 'pending', 'approved', 'rejected') NOT NULL DEFAULT 'none' COMMENT '围栏外打卡审批状态',
      approval_request_id INT DEFAULT NULL COMMENT '关联审批单ID',
      watermark_code VARCHAR(20) DEFAULT NULL COMMENT '水印防伪码',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
      INDEX idx_user_date (user_id, created_at),
      INDEX idx_project_date (project_id, created_at),
      UNIQUE INDEX idx_watermark_code (watermark_code)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：为已有的 checkins 表添加 distance_to_fence 字段
  try {
    await db.execute(`
      ALTER TABLE checkins ADD COLUMN distance_to_fence DOUBLE DEFAULT NULL COMMENT '距离围栏距离(米)'
    `);
    logger.info('已迁移 checkins 表：添加 distance_to_fence 字段');
  } catch (e) {
    // 字段已存在则忽略
  }

  // 迁移：为已有的 checkins 表添加围栏外审批闭环字段
  const checkinApprovalMigrations = [
    {
      col: 'outside_approval_status',
      sql: "ALTER TABLE checkins ADD COLUMN outside_approval_status ENUM('none', 'pending', 'approved', 'rejected') NOT NULL DEFAULT 'none' COMMENT '围栏外打卡审批状态'"
    },
    {
      col: 'approval_request_id',
      sql: "ALTER TABLE checkins ADD COLUMN approval_request_id INT DEFAULT NULL COMMENT '关联审批单ID'"
    },
  ];
  for (const m of checkinApprovalMigrations) {
    try {
      await db.execute(m.sql);
      logger.info(`已迁移 checkins 表：添加 ${m.col} 字段`);
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') {
        logger.error(`迁移 checkins 表 ${m.col} 字段失败`, { error: e.message });
      }
    }
  }

  // 迁移：为已有的 checkins 表添加 watermark_code 字段
  try {
    await db.execute(`
      ALTER TABLE checkins ADD COLUMN watermark_code VARCHAR(20) DEFAULT NULL COMMENT '水印防伪码'
    `);
    await db.execute(`
      ALTER TABLE checkins ADD UNIQUE INDEX idx_watermark_code (watermark_code)
    `);
    logger.info('已迁移 checkins 表：添加 watermark_code 字段');
  } catch (e) {
    // 字段已存在则忽略
  }

  // 迁移：将 type 字段从 ENUM 改为 VARCHAR 以支持自定义类型
  try {
    await db.execute(`
      ALTER TABLE checkins MODIFY COLUMN type VARCHAR(50) NOT NULL COMMENT '打卡类型(in/out/自定义)'
    `);
    logger.info('已迁移 checkins 表：放宽 type 字段限制');
  } catch (e) {
    logger.error('迁移 checkins 表 type 字段失败', { error: e.message });
  }

  // 迁移：为 checkins 表 type 字段添加索引
  try {
    await db.execute(`ALTER TABLE checkins ADD INDEX idx_type (type)`);
    logger.info('已迁移 checkins 表：添加 type 索引');
  } catch (e) {
    // 索引已存在则忽略
  }

  // 创建防伪码表 (30天过期)
  await db.execute(`
    CREATE TABLE IF NOT EXISTS watermark_codes (
      id INT AUTO_INCREMENT PRIMARY KEY,
      code VARCHAR(20) UNIQUE NOT NULL,
      user_id INT NOT NULL,
      status ENUM('pending', 'used', 'expired') NOT NULL DEFAULT 'pending',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      expires_at DATETIME NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_code_status (code, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建位置记录表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS locations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      latitude DOUBLE NOT NULL,
      longitude DOUBLE NOT NULL,
      accuracy DOUBLE DEFAULT NULL,
      speed DOUBLE DEFAULT NULL,
      address VARCHAR(500) DEFAULT '',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_time (user_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建离线打卡缓存表（无网络时本地缓存，有网后同步）
  await db.execute(`
    CREATE TABLE IF NOT EXISTS offline_checkins (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '用户ID',
      type VARCHAR(50) NOT NULL COMMENT '打卡类型',
      latitude DOUBLE DEFAULT NULL,
      longitude DOUBLE DEFAULT NULL,
      address VARCHAR(500) DEFAULT '',
      photo VARCHAR(500) DEFAULT '',
      remark VARCHAR(500) DEFAULT '',
      project_id INT DEFAULT NULL,
      local_timestamp DATETIME NOT NULL COMMENT '设备本地打卡时间',
      synced TINYINT DEFAULT 0 COMMENT '是否已同步(1是/0否)',
      sync_time DATETIME DEFAULT NULL COMMENT '同步时间',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_synced (user_id, synced),
      INDEX idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建设备管理表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS devices (
      id INT AUTO_INCREMENT PRIMARY KEY,
      device_id VARCHAR(100) UNIQUE NOT NULL COMMENT '设备硬件ID/MAC地址等唯一标识',
      name VARCHAR(100) NOT NULL COMMENT '设备自定义名称',
      type ENUM('camera', 'checkpoint', 'beacon', 'other') NOT NULL DEFAULT 'checkpoint' COMMENT '设备分类',
      project_id INT DEFAULT NULL COMMENT '绑定的项目ID',
      status TINYINT NOT NULL DEFAULT 1 COMMENT '1在线/正常 0离线/停用',
      latitude DOUBLE DEFAULT NULL COMMENT '最后已知纬度',
      longitude DOUBLE DEFAULT NULL COMMENT '最后已知经度',
      last_active DATETIME DEFAULT NULL COMMENT '最后活跃时间',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建水印模板表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS watermark_templates (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL COMMENT '模板名称（管理端展示）',
      title VARCHAR(100) DEFAULT NULL COMMENT '水印主标题（手机端展示）',
      schema_json JSON NOT NULL,
      status TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：为 watermark_templates 添加 title 字段（MySQL 不支持 IF NOT EXISTS）
  try {
    await db.execute(`
      ALTER TABLE watermark_templates 
      ADD COLUMN title VARCHAR(100) DEFAULT NULL COMMENT '水印主标题（手机端展示）'
    `);
    logger.info('已迁移 watermark_templates 表：添加 title 字段');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      // 字段已存在，无需操作
    } else {
      logger.warn('watermark_templates 迁移跳过', { error: err.message });
    }
  }

  // 创建考勤组表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS attendance_groups (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL COMMENT '考勤组名称',
      work_start_time TIME NOT NULL COMMENT '上班时间',
      work_end_time TIME NOT NULL COMMENT '下班时间',
      late_tolerance INT DEFAULT 15 COMMENT '允许迟到分钟数',
      early_leave_tolerance INT DEFAULT 15 COMMENT '允许早退分钟数',
      project_id INT DEFAULT NULL COMMENT '绑定项目ID',
      status TINYINT DEFAULT 1 COMMENT '状态(1启用/0停用)',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：为 attendance_groups 添加午休和提醒字段（MySQL 不支持 IF NOT EXISTS，逐条执行）
  const agMigrations = [
    { col: 'lunch_break_start', sql: "ALTER TABLE attendance_groups ADD COLUMN lunch_break_start TIME DEFAULT NULL COMMENT '午休开始时间'" },
    { col: 'lunch_break_end',   sql: "ALTER TABLE attendance_groups ADD COLUMN lunch_break_end TIME DEFAULT NULL COMMENT '午休结束时间'" },
    { col: 'remind_before_minutes', sql: "ALTER TABLE attendance_groups ADD COLUMN remind_before_minutes INT DEFAULT 5 COMMENT '上班前提醒分钟数'" },
    { col: 'remind_after_clockout', sql: "ALTER TABLE attendance_groups ADD COLUMN remind_after_clockout TINYINT DEFAULT 1 COMMENT '下班后是否提醒签退'" },
  ];
  for (const m of agMigrations) {
    try {
      await db.execute(m.sql);
      logger.info(`已迁移 attendance_groups 表：添加 ${m.col} 字段`);
    } catch (err) {
      if (err.code === 'ER_DUP_FIELDNAME') {
        // 字段已存在，无需操作
      } else {
        logger.warn(`attendance_groups.${m.col} 迁移跳过`, { error: err.message });
      }
    }
  }

  // 创建考勤组成员表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS attendance_group_members (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      user_id INT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES attendance_groups(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY uk_group_user (group_id, user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建班次表（支持多班次：早班、晚班、轮班等）
  await db.execute(`
    CREATE TABLE IF NOT EXISTS shifts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL COMMENT '班次名称（如：早班、晚班、夜班）',
      start_time TIME NOT NULL COMMENT '上班时间',
      end_time TIME NOT NULL COMMENT '下班时间',
      late_tolerance INT DEFAULT 15 COMMENT '允许迟到分钟数',
      early_leave_tolerance INT DEFAULT 15 COMMENT '允许早退分钟数',
      color VARCHAR(20) DEFAULT '#3B82F6' COMMENT '班次颜色标识',
      sort_order INT DEFAULT 0 COMMENT '排序',
      status TINYINT DEFAULT 1 COMMENT '状态(1启用/0停用)',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 初始化默认班次
  const [shiftRows] = await db.execute('SELECT count(*) as count FROM shifts');
  if (shiftRows[0].count === 0) {
    await db.execute(`
      INSERT INTO shifts (name, start_time, end_time, late_tolerance, early_leave_tolerance, color, sort_order) VALUES
      ('白班', '08:00:00', '17:00:00', 15, 15, '#22C55E', 1),
      ('早班', '06:00:00', '14:00:00', 15, 15, '#3B82F6', 2),
      ('晚班', '14:00:00', '22:00:00', 15, 15, '#F59E0B', 3),
      ('夜班', '22:00:00', '06:00:00', 15, 15, '#8B5CF6', 4)
    `);
    logger.info('已初始化默认班次数据');
  }

  // 创建排班表（用户-日期-班次关联）
  await db.execute(`
    CREATE TABLE IF NOT EXISTS user_schedules (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '用户ID',
      date DATE NOT NULL COMMENT '排班日期',
      shift_id INT NOT NULL COMMENT '班次ID',
      is_rest TINYINT DEFAULT 0 COMMENT '是否休息(1是/0否)',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
      UNIQUE KEY uk_user_date (user_id, date),
      INDEX idx_date (date),
      INDEX idx_user_id (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建考勤结果表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS attendance_results (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '用户ID',
      date DATE NOT NULL COMMENT '考勤日期',
      status ENUM('normal', 'late', 'early_leave', 'absent', 'leave', 'holiday', 'rest') NOT NULL DEFAULT 'absent' COMMENT '考勤状态',
      checkin_time TIME DEFAULT NULL COMMENT '上班打卡时间',
      checkout_time TIME DEFAULT NULL COMMENT '下班打卡时间',
      shift_id INT DEFAULT NULL COMMENT '班次ID',
      group_id INT DEFAULT NULL COMMENT '考勤组ID',
      overtime TINYINT NOT NULL DEFAULT 0 COMMENT '是否加班',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL,
      FOREIGN KEY (group_id) REFERENCES attendance_groups(id) ON DELETE SET NULL,
      UNIQUE KEY uk_user_date (user_id, date),
      INDEX idx_date (date),
      INDEX idx_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：为已有的 attendance_results 表添加 overtime 字段
  try {
    await db.execute(`
      ALTER TABLE attendance_results ADD COLUMN overtime TINYINT NOT NULL DEFAULT 0 COMMENT '是否加班'
    `);
    logger.info('已迁移 attendance_results 表：添加 overtime 字段');
  } catch (e) {
    if (e.code !== 'ER_DUP_FIELDNAME') {
      logger.error('迁移 attendance_results 表 overtime 字段失败', { error: e.message });
    }
  }

  // 创建节假日表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS holidays (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL COMMENT '节假日名称',
      date DATE NOT NULL COMMENT '日期',
      type ENUM('holiday', 'workday') NOT NULL DEFAULT 'holiday' COMMENT '类型：holiday放假, workday调休上班',
      year INT NOT NULL COMMENT '年份',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY uk_date (date),
      INDEX idx_year (year)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建审批申请表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS approval_requests (
      id INT AUTO_INCREMENT PRIMARY KEY,
      type ENUM('补卡', '请假', '加班', '异常打卡') NOT NULL COMMENT '申请类型',
      user_id INT NOT NULL COMMENT '申请人ID',
      checkin_id INT DEFAULT NULL COMMENT '关联打卡记录ID',
      reason TEXT NOT NULL COMMENT '申请原因',
      start_date DATE NOT NULL COMMENT '开始日期',
      end_date DATE NOT NULL COMMENT '结束日期',
      status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending' COMMENT '审批状态',
      approver_id INT DEFAULT NULL COMMENT '审批人ID',
      approved_at DATETIME DEFAULT NULL COMMENT '审批时间',
      remark VARCHAR(500) DEFAULT NULL COMMENT '审批备注',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL,
      INDEX idx_user_status (user_id, status),
      INDEX idx_checkin_id (checkin_id),
      INDEX idx_status (status),
      INDEX idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 迁移：扩展审批类型并关联异常打卡记录
  try {
    await db.execute(`
      ALTER TABLE approval_requests MODIFY COLUMN type ENUM('补卡', '请假', '加班', '异常打卡') NOT NULL COMMENT '申请类型'
    `);
    logger.info('已迁移 approval_requests 表：支持异常打卡审批类型');
  } catch (e) {
    logger.error('迁移 approval_requests 表 type 字段失败', { error: e.message });
  }

  try {
    await db.execute(`
      ALTER TABLE approval_requests ADD COLUMN checkin_id INT DEFAULT NULL COMMENT '关联打卡记录ID' AFTER user_id
    `);
    logger.info('已迁移 approval_requests 表：添加 checkin_id 字段');
  } catch (e) {
    if (e.code !== 'ER_DUP_FIELDNAME') {
      logger.error('迁移 approval_requests 表 checkin_id 字段失败', { error: e.message });
    }
  }

  try {
    await db.execute(`ALTER TABLE approval_requests ADD INDEX idx_checkin_id (checkin_id)`);
    logger.info('已迁移 approval_requests 表：添加 checkin_id 索引');
  } catch (e) {
    if (e.code !== 'ER_DUP_KEYNAME') {
      logger.error('迁移 approval_requests 表 checkin_id 索引失败', { error: e.message });
    }
  }

  // 创建打卡类型表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS checkin_types (
      id INT AUTO_INCREMENT PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL COMMENT '类型编码',
      name VARCHAR(100) NOT NULL COMMENT '类型名称',
      icon VARCHAR(50) DEFAULT '' COMMENT '图标名',
      color VARCHAR(20) DEFAULT '#3B82F6' COMMENT '显示颜色',
      category ENUM('attendance', 'business', 'inspection') NOT NULL DEFAULT 'business' COMMENT '大类: 考勤/业务/巡检',
      count_as_attendance TINYINT NOT NULL DEFAULT 0 COMMENT '是否计入考勤统计',
      sort_order INT DEFAULT 0 COMMENT '排序',
      status TINYINT NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 初始打卡类型
  const [typeRows] = await db.execute('SELECT count(*) as count FROM checkin_types');
  if (typeRows[0].count === 0) {
    await db.execute(`INSERT INTO checkin_types (code, name, icon, color, category, count_as_attendance, sort_order) VALUES
      ('clock_in', '上班打卡', 'login', '#22C55E', 'attendance', 1, 1),
      ('clock_out', '下班打卡', 'logout', '#EF4444', 'attendance', 1, 2),
      ('site_visit', '实地考察', 'explore', '#3B82F6', 'business', 0, 3),
      ('progress', '项目进度上报', 'trending_up', '#F59E0B', 'business', 0, 4),
      ('safety', '安全检查', 'security', '#EF4444', 'inspection', 0, 5),
      ('device', '设备位置上报', 'devices', '#8B5CF6', 'inspection', 0, 6),
      ('custom', '自定义', 'edit', '#6B7280', 'business', 0, 99)
    `);
    logger.info('已初始化打卡类型数据');
  }

  // 创建消息通知表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS notifications (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '接收用户ID',
      title VARCHAR(200) NOT NULL COMMENT '消息标题',
      content TEXT NOT NULL COMMENT '消息内容',
      type ENUM('system', 'checkin', 'project', 'alert') NOT NULL DEFAULT 'system' COMMENT '消息类型',
      is_read TINYINT NOT NULL DEFAULT 0 COMMENT '是否已读 0未读 1已读',
      extra_data JSON DEFAULT NULL COMMENT '额外数据',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_read (user_id, is_read),
      INDEX idx_user_created (user_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 创建 sessions 表 - 存储 refresh token
  await db.execute(`
    CREATE TABLE IF NOT EXISTS sessions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '用户ID',
      refresh_token VARCHAR(255) UNIQUE NOT NULL COMMENT 'Refresh Token',
      device_info VARCHAR(500) DEFAULT NULL COMMENT '设备信息',
      ip_address VARCHAR(45) DEFAULT NULL COMMENT 'IP地址',
      expires_at DATETIME NOT NULL COMMENT '过期时间',
      platform VARCHAR(32) DEFAULT NULL COMMENT '平台',
      device_id VARCHAR(64) DEFAULT NULL COMMENT '设备ID',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_id (user_id),
      INDEX idx_refresh_token (refresh_token),
      INDEX idx_expires_at (expires_at),
      INDEX idx_user_platform (user_id, platform)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  try {
    await db.execute(`ALTER TABLE sessions ADD COLUMN platform VARCHAR(32) DEFAULT NULL COMMENT '平台'`);
  } catch (e) {
    if (e.code !== 'ER_DUP_FIELDNAME') {
      logger.error('迁移 sessions 表 platform 字段失败', { error: e.message });
    }
  }

  try {
    await db.execute(`ALTER TABLE sessions ADD COLUMN device_id VARCHAR(64) DEFAULT NULL COMMENT '设备ID'`);
  } catch (e) {
    if (e.code !== 'ER_DUP_FIELDNAME') {
      logger.error('迁移 sessions 表 device_id 字段失败', { error: e.message });
    }
  }

  try {
    await db.execute(`ALTER TABLE sessions ADD INDEX idx_user_platform (user_id, platform)`);
  } catch (e) {
    if (e.code !== 'ER_DUP_KEYNAME') {
      logger.error('迁移 sessions 表 idx_user_platform 索引失败', { error: e.message });
    }
  }

  // AI 会话表
  await db.execute(`
    CREATE TABLE IF NOT EXISTS ai_conversations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL COMMENT '发起用户ID',
      title VARCHAR(120) NOT NULL DEFAULT '新对话',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      deleted_at DATETIME DEFAULT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_updated (user_id, updated_at),
      INDEX idx_deleted (deleted_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS ai_messages (
      id INT AUTO_INCREMENT PRIMARY KEY,
      conversation_id INT NOT NULL,
      user_id INT NOT NULL,
      role ENUM('user', 'assistant', 'tool') NOT NULL,
      content TEXT NOT NULL,
      metadata JSON DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_conversation_created (conversation_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS ai_action_requests (
      id INT AUTO_INCREMENT PRIMARY KEY,
      conversation_id INT NOT NULL,
      user_id INT NOT NULL,
      action_type VARCHAR(80) NOT NULL,
      title VARCHAR(160) NOT NULL,
      payload JSON NOT NULL,
      status ENUM('pending', 'confirmed', 'rejected', 'expired', 'failed') NOT NULL DEFAULT 'pending',
      result JSON DEFAULT NULL,
      confirmed_at DATETIME DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_status (user_id, status),
      INDEX idx_action_type (action_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS ai_audit_logs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      action_type VARCHAR(80) NOT NULL,
      payload JSON DEFAULT NULL,
      result JSON DEFAULT NULL,
      ip_address VARCHAR(45) DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user_created (user_id, created_at),
      INDEX idx_action_type (action_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // 初始水印模板
  const [wmRows] = await db.execute('SELECT count(*) as count FROM watermark_templates');
  if (wmRows[0].count === 0) {
    const classicSchema = JSON.stringify({
      layout: "classic",
      x: 0.05,
      y: 0.65,
      items: [
        { type: "custom_name", x: 0.05, y: 0.1, size: 28, color: "#FFFFFF", bgColor: "#00000077" },
        { type: "time", x: 0.05, y: 0.3, size: 60, color: "#FFA500", bold: true },
        { type: "user", x: 0.05, y: 0.6, size: 20, color: "#D3D3D3", bgColor: "#00000077" },
        { type: "location", x: 0.05, y: 0.7, size: 20, color: "#D3D3D3", bgColor: "#00000077" },
        { type: "code", x: 0.05, y: 0.85, size: 16, color: "#FFFFFF66", bgColor: "#00000077" }
      ]
    });
    const minimalSchema = JSON.stringify({
      layout: "minimal",
      x: 0.05,
      y: 0.7,
      items: [
        { type: "custom_name", x: 0.02, y: 0.02, size: 30, color: "#4F8CFF", shadow: true },
        { type: "time", x: 0.02, y: 0.2, size: 68, color: "#4F8CFF", shadow: true, bold: true },
        { type: "date", x: 0.02, y: 0.5, size: 18, color: "#FFFFFF", shadow: true },
        { type: "location", x: 0.02, y: 0.65, size: 14, color: "#FFFFFF", shadow: true },
        { type: "code", x: 0.02, y: 0.85, size: 14, color: "#FFFFFFaa", shadow: true }
      ]
    });
    const bottomBarSchema = JSON.stringify({
      layout: "bottom_bar",
      x: 0.0,
      y: 0.8,
      items: [
        { type: "time", x: 0.05, y: 0.2, size: 60, color: "#FFFFFF", bold: true },
        { type: "custom_user", x: 0.05, y: 0.5, size: 22, color: "#FFFFFF" },
        { type: "location", x: 0.05, y: 0.7, size: 18, color: "#D3D3D3" },
        { type: "code", x: 0.95, y: 0.8, size: 14, color: "#FFFFFF66", align: "right" }
      ]
    });
    const workCardSchema = JSON.stringify({
      layout: "work_card",
      x: 0.05,
      y: 0.6,
      items: [
        { type: "custom_name", x: 0.05, y: 0.05, size: 32, color: "#FFFFFF", bold: true },
        { type: "time", x: 0.05, y: 0.3, size: 84, color: "#FFFFFF", bold: true },
        { type: "date", x: 0.05, y: 0.6, size: 24, color: "#FFFFFFCC" },
        { type: "address", x: 0.05, y: 0.75, size: 24, color: "#FFFFFFCC" },
        { type: "user", x: 0.05, y: 0.9, size: 18, color: "#FFFFFF99" }
      ]
    });
    await db.execute('INSERT INTO watermark_templates (name, schema_json) VALUES (?, ?)', ['经典背板', classicSchema]);
    await db.execute('INSERT INTO watermark_templates (name, schema_json) VALUES (?, ?)', ['极简无底', minimalSchema]);
    await db.execute('INSERT INTO watermark_templates (name, schema_json) VALUES (?, ?)', ['工业打卡', workCardSchema]);
    await db.execute('INSERT INTO watermark_templates (name, schema_json) VALUES (?, ?)', ['全底挂边', bottomBarSchema]);
    logger.info('已初始化动态水印模板配置');
  }

  // 创建默认管理员（如不存在）
  const [rows] = await db.execute('SELECT id FROM users WHERE username = ?', [config.defaultAdmin.username]);
  if (rows.length === 0) {
    const hashedPassword = await bcrypt.hash(config.defaultAdmin.password, 10);
    await db.execute(
      'INSERT INTO users (username, password, name, role, phone) VALUES (?, ?, ?, ?, ?)',
      [
        config.defaultAdmin.username,
        hashedPassword,
        config.defaultAdmin.name,
        config.defaultAdmin.role,
        config.defaultAdmin.phone
      ]
    );
    logger.info('已创建默认管理员账号', { username: config.defaultAdmin.username });
  }

  logger.info('数据库初始化完成');
}

module.exports = { getPool, initDatabase, closePool };
