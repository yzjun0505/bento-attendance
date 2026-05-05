/**
 * Jest 测试配置
 */
module.exports = {
  // 测试环境
  testEnvironment: 'node',

  // 测试文件匹配模式
  testMatch: ['**/tests/**/*.test.js'],

  // 测试超时时间（毫秒）
  testTimeout: 30000,

  // 测试前执行的 setup 文件
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],

  // 覆盖率收集目录
  collectCoverageFrom: [
    'controllers/**/*.js',
    'routes/**/*.js',
    'middleware/**/*.js',
    'utils/**/*.js',
    '!**/node_modules/**',
    '!**/tests/**'
  ],

  // 覆盖率报告输出目录
  coverageDirectory: 'coverage',

  // 覆盖率报告格式
  coverageReporters: ['text', 'text-summary', 'html', 'lcov'],

  // 覆盖率阈值（当前为起步阶段，阈值设低，后续逐步提高）
  coverageThreshold: {
    global: {
      branches: 15,
      functions: 25,
      lines: 30,
      statements: 30
    }
  },

  // 清理模拟数据
  clearMocks: true,

  // 恢复模拟数据
  restoreMocks: true,

  // 详细输出
  verbose: true
};
