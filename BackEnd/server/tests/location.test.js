/**
 * 位置模块接口测试
 * 覆盖：上报位置、获取最新位置、位置历史
 */
const request = require('supertest');
const { app } = require('../app');

describe('位置模块 API 测试', () => {
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

  describe('POST /api/location/report', () => {
    test('正常上报位置成功', async () => {
      const res = await request(app)
        .post('/api/location/report')
        .set('Authorization', `Bearer ${token}`)
        .send({
          latitude: 39.9042,
          longitude: 116.4074,
          accuracy: 10.5,
          speed: 2.5,
          address: '北京市东城区测试位置'
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('缺少经纬度返回 400', async () => {
      const res = await request(app)
        .post('/api/location/report')
        .set('Authorization', `Bearer ${token}`)
        .send({
          address: '只有地址没有坐标'
        });

      expect(res.status).toBe(400);
    });

    test('未登录上报返回 401', async () => {
      const res = await request(app)
        .post('/api/location/report')
        .send({
          latitude: 39.9042,
          longitude: 116.4074
        });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/location/latest', () => {
    test('获取最新位置列表', async () => {
      const res = await request(app)
        .get('/api/location/latest')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('未登录返回 401', async () => {
      const res = await request(app)
        .get('/api/location/latest');

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/location/online-count', () => {
    test('获取在线人数', async () => {
      const res = await request(app)
        .get('/api/location/online-count')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('online');
      expect(typeof res.body.data.online).toBe('number');
    });
  });
});
