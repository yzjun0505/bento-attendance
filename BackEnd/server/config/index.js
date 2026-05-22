/**
 * 服务器配置
 */
module.exports = {
  // 服务端口
  port: process.env.PORT || 3000,

  // MongoDB (Atlas) 配置 - 用于扩展能力/运行依赖（可选）
  mongo: {
    // 推荐通过环境变量注入，避免把账号密码写进代码仓库
    uri: process.env.MONGODB_URI || '',
    dbName: process.env.MONGODB_DB || 'bento',
    // 是否把 Mongo 作为强依赖：连接失败将导致后端启动失败
    required: process.env.MONGODB_REQUIRED === 'true' || false,
  },

  // MySQL (本地) 数据库配置
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'user_information',
    waitForConnections: true,
    connectionLimit: 50,
    queueLimit: 0,
    idleTimeout: 60000,
    maxIdle: 25,
  },

  // JWT 配置
  jwt: {
    secret: process.env.JWT_SECRET || '',
    expiresIn: process.env.JWT_EXPIRES_IN || '12h',
    refreshSecret: process.env.JWT_REFRESH_SECRET || '',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  },

  // 默认管理员
  defaultAdmin: {
    username: process.env.ADMIN_USERNAME || 'admin',
    password: process.env.ADMIN_PASSWORD || '',
    name: '系统管理员',
    role: 'admin',
    phone: '13800000000'
  },

  // 高德地图 API Key
  amapKey: process.env.AMAP_KEY || '',

  // AI 助手配置：兼容 OpenAI 风格 /chat/completions 接口
  ai: {
    apiKey: process.env.AI_API_KEY || '',
    baseUrl: process.env.AI_BASE_URL || 'https://api.openai.com/v1',
    model: process.env.AI_MODEL || '',
    timeout: Number(process.env.AI_TIMEOUT_MS || 30000),
  },

  // 上传文件配置
  upload: {
    maxSize: 5 * 1024 * 1024, // 5MB
    dest: './uploads'
  }
};
