/**
 * 轨迹回放模块接口测试
 * 覆盖：个人轨迹查询、热力图数据
 */
const request = require('supertest');
const { app } = require('../app');

const adminUser = {
  username: 'trackadmin' + Date.now(),
  password: 'admin123456',
  name: '轨迹管理员',
  role: 'admin'
};

const workerUser = {
  username: 'trackworker' + Date.now(),
  password: 'worker123456',
  name: '轨迹员工'
};

let adminToken = null;
let workerToken = null;
let workerId = null;

describe('轨迹回放 API 测试', () => {
  beforeAll(async () => {
    const adminReg = await request(app).post('/api/auth/register').send(adminUser);
    const adminLogin = await request(app).post('/api/auth/login').send({
      username: adminUser.username,
      password: adminUser.password
    });
    adminToken = adminLogin.body.data.access_token || adminLogin.body.data.token;

    const workerReg = await request(app).post('/api/auth/register').send(workerUser);
    workerId = workerReg.body.data.id;
    const workerLogin = await request(app).post('/api/auth/login').send({
      username: workerUser.username,
      password: workerUser.password
    });
    workerToken = workerLogin.body.data.access_token || workerLogin.body.data.token;

    // 上报一些位置数据用于轨迹测试
    const today = new Date().toISOString().slice(0, 10);
    await request(app)
      .post('/api/location/report')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({ latitude: 39.9042, longitude: 116.4074, address: '位置1' });

    await request(app)
      .post('/api/location/report')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({ latitude: 39.9050, longitude: 116.4080, address: '位置2' });
  });

  // ========== 获取个人轨迹 ==========
  describe('GET /api/tracks/:userId', () => {
    test('管理员获取员工轨迹', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/${workerId}?date=${today}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('user');
      expect(res.body.data).toHaveProperty('track');
      expect(res.body.data).toHaveProperty('total_points');
      expect(res.body.data).toHaveProperty('total_distance');
      expect(res.body.data).toHaveProperty('stay_points');
      expect(Array.isArray(res.body.data.track)).toBe(true);
    });

    test('缺少日期返回 400', async () => {
      const res = await request(app)
        .get(`/api/tracks/${workerId}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(400);
    });

    test('员工无权限查看他人轨迹', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/${workerId}?date=${today}`)
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(403);
    });

    test('未登录返回 401', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/${workerId}?date=${today}`);

      expect(res.status).toBe(401);
    });

    test('查询不存在的用户返回空轨迹', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/99999?date=${today}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.track.length).toBe(0);
    });
  });

  // ========== 热力图数据 ==========
  describe('GET /api/tracks/heatmap', () => {
    test('管理员获取热力图数据', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/heatmap?date_start=${today}&date_end=${today}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('员工无权限获取热力图', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/tracks/heatmap?date_start=${today}&date_end=${today}`)
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(403);
    });

    test('未登录返回 401', async () => {
      const res = await request(app).get('/api/tracks/heatmap');
      expect(res.status).toBe(401);
    });
  });
});
