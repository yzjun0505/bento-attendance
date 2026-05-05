/**
 * 健康检查接口测试
 * 无需登录，用于监控和探活
 */
const request = require('supertest');
const { app } = require('../app');

describe('健康检查 API 测试', () => {
  test('GET /api/health 返回服务状态', async () => {
    const res = await request(app)
      .get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('code');
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('services');
    expect(res.body.services).toHaveProperty('mysql');
  });

  test('健康检查响应时间小于 2 秒', async () => {
    const start = Date.now();
    const res = await request(app).get('/api/health');
    const duration = Date.now() - start;

    expect(res.status).toBe(200);
    expect(duration).toBeLessThan(2000);
  });
});
