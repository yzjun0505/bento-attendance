/**
 * 测试环境初始化
 * 使用独立的测试数据库，避免污染开发数据
 */
const path = require('path');
const fs = require('fs');

// 加载测试环境变量
const envPath = path.join(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  require('dotenv').config({ path: envPath });
}

// 测试数据库配置（覆盖正式配置）
process.env.DB_NAME = 'user_information_test';
process.env.NODE_ENV = 'test';

// 开启 OpenIM Mock 模式，避免测试时连接真实 OpenIM 服务报错
process.env.OPENIM_MOCK_MODE = 'true';

const { initDatabase, getPool, closePool } = require('../models/db');

let db;

beforeAll(async () => {
  // 初始化测试数据库
  await initDatabase();
  db = getPool();
});

afterAll(async () => {
  // 清理测试数据并关闭连接
  if (db) {
    await db.execute('DELETE FROM checkins WHERE user_id > 10000');
    await db.execute('DELETE FROM users WHERE id > 10000');
    await closePool();
  }
});

module.exports = { getTestDb: () => db };
