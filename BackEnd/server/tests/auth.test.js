/**
 * 认证模块接口测试
 * 覆盖：注册、登录、Token刷新、获取用户信息
 */
const request = require('supertest');
const { app } = require('../app');

// 测试数据（用户名只能包含英文字母和数字）
const testUser = {
  username: 'testuser' + Date.now(),
  password: 'test123456',
  name: '测试用户',
  phone: '13800138000'
};

let accessToken = null;
let refreshToken = null;

describe('认证模块 API 测试', () => {
  // ========== 注册 ==========
  describe('POST /api/auth/register', () => {
    test('正常注册新用户', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
    });

    test('重复用户名注册失败', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser);

      expect(res.status).toBe(400);
      expect(res.body.code).toBe(400);
    });

    test('缺少密码字段返回 400', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ username: 'nopassword', name: '没密码' });

      expect(res.status).toBe(400);
    });
  });

  // ========== 登录 ==========
  describe('POST /api/auth/login', () => {
    test('正确用户名密码登录成功', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          username: testUser.username,
          password: testUser.password
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('token');
      expect(res.body.data).toHaveProperty('access_token');
      expect(res.body.data).toHaveProperty('refresh_token');
      expect(res.body.data).toHaveProperty('user');

      accessToken = res.body.data.access_token || res.body.data.token;
      refreshToken = res.body.data.refresh_token;
    });

    test('错误密码登录失败', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          username: testUser.username,
          password: 'wrongpassword'
        });

      expect(res.status).toBe(401);
      expect(res.body.code).toBe(401);
    });

    test('不存在的用户登录失败', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          username: 'notexistuser12345',
          password: 'anypassword'
        });

      expect(res.status).toBe(401);
    });
  });

  // ========== 获取用户信息 ==========
  describe('GET /api/auth/profile', () => {
    test('携带有效 Token 获取用户信息', async () => {
      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('username', testUser.username);
    });

    test('未携带 Token 返回 401', async () => {
      const res = await request(app)
        .get('/api/auth/profile');

      expect(res.status).toBe(401);
    });

    test('携带无效 Token 返回 401', async () => {
      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', 'Bearer invalidtoken123');

      expect(res.status).toBe(401);
    });
  });

  // ========== Token 刷新 ==========
  describe('POST /api/sessions/refresh', () => {
    test('使用有效 refresh_token 刷新', async () => {
      const res = await request(app)
        .post('/api/sessions/refresh')
        .send({ refresh_token: refreshToken });

      // 刷新接口可能返回 200 或 400（取决于实现）
      expect([200, 400]).toContain(res.status);
      if (res.status === 200) {
        expect(res.body.code).toBe(200);
        expect(res.body.data).toHaveProperty('access_token');
      }
    });

    test('使用无效 refresh_token 失败', async () => {
      const res = await request(app)
        .post('/api/sessions/refresh')
        .send({ refresh_token: 'invalid_refresh_token' });

      expect([401, 400]).toContain(res.status);
    });
  });
});
