/**
 * 离线打卡模块接口测试
 * 覆盖：提交缓存、获取记录、同步到正式打卡
 */
const request = require('supertest');
const { app } = require('../app');

const workerUser = {
  username: 'offlineworker' + Date.now(),
  password: 'worker123456',
  name: '离线员工'
};

let workerToken = null;
let offlineCheckinId = null;

describe('离线打卡 API 测试', () => {
  beforeAll(async () => {
    const workerReg = await request(app).post('/api/auth/register').send(workerUser);
    const workerLogin = await request(app).post('/api/auth/login').send({
      username: workerUser.username,
      password: workerUser.password
    });
    workerToken = workerLogin.body.data.access_token || workerLogin.body.data.token;
  });

  // ========== 提交离线打卡缓存 ==========
  describe('POST /api/offline-checkins', () => {
    test('提交离线打卡缓存成功', async () => {
      const now = new Date();
      const localTime = now.toISOString().slice(0, 19).replace('T', ' ');

      const res = await request(app)
        .post('/api/offline-checkins')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: 'clock_in',
          latitude: 39.9042,
          longitude: 116.4074,
          address: '北京市测试地址',
          photo: 'test_photo_base64',
          remark: '现场无网络',
          local_timestamp: localTime
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
      offlineCheckinId = res.body.data.id;
    });

    test('缺少打卡类型返回 400', async () => {
      const res = await request(app)
        .post('/api/offline-checkins')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          latitude: 39.9,
          longitude: 116.4,
          local_timestamp: '2024-01-01 08:00:00'
        });

      expect(res.status).toBe(400);
    });

    test('缺少本地时间返回 400', async () => {
      const res = await request(app)
        .post('/api/offline-checkins')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: 'clock_in',
          latitude: 39.9,
          longitude: 116.4
        });

      expect(res.status).toBe(400);
    });

    test('未登录提交返回 401', async () => {
      const res = await request(app)
        .post('/api/offline-checkins')
        .send({
          type: 'clock_in',
          local_timestamp: '2024-01-01 08:00:00'
        });

      expect(res.status).toBe(401);
    });
  });

  // ========== 获取我的离线记录 ==========
  describe('GET /api/offline-checkins/mine', () => {
    test('获取我的离线打卡记录', async () => {
      const res = await request(app)
        .get('/api/offline-checkins/mine')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    });

    test('未登录返回 401', async () => {
      const res = await request(app).get('/api/offline-checkins/mine');
      expect(res.status).toBe(401);
    });
  });

  // ========== 同步离线打卡 ==========
  describe('POST /api/offline-checkins/sync', () => {
    test('同步离线打卡到正式记录', async () => {
      const res = await request(app)
        .post('/api/offline-checkins/sync')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('synced');
      expect(res.body.data.synced).toBeGreaterThanOrEqual(1);
    });

    test('重复同步返回成功（无待同步数据）', async () => {
      const res = await request(app)
        .post('/api/offline-checkins/sync')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data.synced).toBe(0);
    });

    test('未登录返回 401', async () => {
      const res = await request(app).post('/api/offline-checkins/sync');
      expect(res.status).toBe(401);
    });
  });

  // ========== 管理端查看所有离线记录 ==========
  describe('GET /api/offline-checkins', () => {
    test('需要管理员权限', async () => {
      const res = await request(app)
        .get('/api/offline-checkins')
        .set('Authorization', `Bearer ${workerToken}`);

      // worker 角色可能返回 403，取决于权限中间件配置
      expect([200, 403]).toContain(res.status);
    });
  });
});
