/**
 * 数据看板接口测试
 * 覆盖：统计数据、趋势数据、分布数据、异常记录
 */
const request = require('supertest');
const { app } = require('../app');

describe('数据看板 API 测试', () => {
  let token = null;

  // 登录获取 token
  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' });

    if (res.status === 200 && res.body.code === 200) {
      token = res.body.data.access_token;
    }
  });

  describe('GET /api/dashboard/stats', () => {
    test('获取看板统计数据', async () => {
      const res = await request(app)
        .get('/api/dashboard/stats')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('totalAttendance');
      expect(res.body.data).toHaveProperty('currentOnline');
      expect(res.body.data).toHaveProperty('abnormalCount');
      expect(res.body.data).toHaveProperty('activeProjects');
    });

    test('未登录返回 401', async () => {
      const res = await request(app)
        .get('/api/dashboard/stats');

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/dashboard/trend', () => {
    test('获取出勤趋势（默认7天）', async () => {
      const res = await request(app)
        .get('/api/dashboard/trend')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('获取30天趋势', async () => {
      const res = await request(app)
        .get('/api/dashboard/trend?days=30')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });
  });

  describe('GET /api/dashboard/distribution', () => {
    test('获取今日打卡状态分布', async () => {
      const res = await request(app)
        .get('/api/dashboard/distribution')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('normal');
      expect(res.body.data).toHaveProperty('late');
      expect(res.body.data).toHaveProperty('leave');
      expect(res.body.data).toHaveProperty('absent');
    });
  });

  describe('GET /api/dashboard/anomalies', () => {
    test('获取异常打卡预警', async () => {
      const res = await request(app)
        .get('/api/dashboard/anomalies?limit=5')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });
  });
});
