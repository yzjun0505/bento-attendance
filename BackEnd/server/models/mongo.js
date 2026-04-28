/**
 * MongoDB 连接管理（Atlas）
 * - 统一连接初始化、复用与健康检查
 * - 默认可选：未配置 MONGODB_URI 时不会连接
 */
const { MongoClient } = require('mongodb');
const config = require('../config');

let client = null;
let db = null;
let lastError = null;

function isEnabled() {
  return Boolean(config.mongo && config.mongo.uri);
}

async function connectMongo() {
  if (!isEnabled()) {
    console.log('ℹ️ MongoDB 未配置（MONGODB_URI 为空），跳过连接');
    return { enabled: false, ok: true };
  }

  if (client && db) {
    return { enabled: true, ok: true };
  }

  try {
    const uri = config.mongo.uri;
    client = new MongoClient(uri, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 10000,
      maxPoolSize: 20,
    });
    await client.connect();
    db = client.db(config.mongo.dbName);

    // 快速探活
    await db.command({ ping: 1 });
    console.log(`✅ MongoDB 已连接: db=${config.mongo.dbName}`);
    lastError = null;
    return { enabled: true, ok: true };
  } catch (err) {
    lastError = err;
    console.error('❌ MongoDB 连接失败:', err.message);
    if (config.mongo.required) {
      throw err;
    }
    // 可选模式：失败不阻断启动，但健康检查会体现为失败
    return { enabled: true, ok: false, error: err.message };
  }
}

function getMongoDb() {
  if (!db) {
    throw new Error('MongoDB 未连接，请先调用 connectMongo()');
  }
  return db;
}

async function mongoHealth() {
  if (!isEnabled()) {
    return { enabled: false, ok: true };
  }
  if (!client || !db) {
    return { enabled: true, ok: false, error: lastError?.message || 'not connected' };
  }
  try {
    await db.command({ ping: 1 });
    return { enabled: true, ok: true };
  } catch (err) {
    lastError = err;
    return { enabled: true, ok: false, error: err.message };
  }
}

async function closeMongo() {
  if (client) {
    await client.close();
  }
  client = null;
  db = null;
  lastError = null;
}

module.exports = {
  connectMongo,
  getMongoDb,
  mongoHealth,
  closeMongo,
};

