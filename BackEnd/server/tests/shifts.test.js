/**
 * 班次管理模块接口测试
 * 覆盖：班次CRUD、列表查询、权限控制
 */
const request = require('supertest');
const { app } = require('../app');

// 测试数据
const adminUser = {
  username: 'shiftadmin' + Date.now(),
  password: 'admin123456',
  name: '班次管理员',
  role: 'admin'
};

const workerUser = {
  username: 'worker' + Date.now(),
  password: 'worker123456',
  name: '员工',
  role: 'worker'
};

let adminToken = null;
let workerToken = null;
let testShiftId = null;

describe('班次管理 API 测试', () => {
  // 注册并登录两个测试用户
  beforeAll(async () => {
    // 注册管理员
    await request(app).post('/api/auth/register').send(adminUser);
    const adminLogin = await request(app).post('/api/auth/login').send({
      username: adminUser.username,
      password: adminUser.password
    });
    adminToken = adminLogin.body.data.access_token || adminLogin.body.data.token;

    // 注册员工
    await request(app).post('/api/auth/register').send(workerUser);
    const workerLogin = await request(app).post('/api/auth/login').send({
      username: workerUser.username,
      password: workerUser.password
    });
    workerToken = workerLogin.body.data.access_token || workerLogin.body.data.token;
  });

  // ========== 创建班次 ==========
  describe('POST /api/shifts', () => {
    test('管理员创建班次成功', async () => {
      const res = await request(app)
        .post('/api/shifts')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: '测试早班',
          start_time: '06:00:00',
          end_time: '14:00:00',
          late_tolerance: 10,
          early_leave_tolerance: 10,
          color: '#FF0000',
          sort_order: 1
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
      testShiftId = res.body.data.id;
    });

    test('缺少必填字段返回 400', async () => {
      const res = await request(app)
        .post('/api/shifts')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: '不完整班次' });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe(400);
    });

    test('普通员工无权限创建班次', async () => {
      const res = await request(app)
        .post('/api/shifts')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          name: '员工创建班次',
          start_time: '08:00:00',
          end_time: '17:00:00'
        });

      expect(res.status).toBe(403);
    });

    test('未登录创建班次返回 401', async () => {
      const res = await request(app)
        .post('/api/shifts')
        .send({ name: '未登录班次', start_time: '08:00:00', end_time: '17:00:00' });

      expect(res.status).toBe(401);
    });
  });

  // ========== 获取班次列表 ==========
  describe('GET /api/shifts', () => {
    test('管理员获取班次列表', async () => {
      const res = await request(app)
        .get('/api/shifts')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('list');
      expect(Array.isArray(res.body.data.list)).toBe(true);
      expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
    });

    test('员工可以查看班次列表', async () => {
      const res = await request(app)
        .get('/api/shifts')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('按关键词搜索班次', async () => {
      const res = await request(app)
        .get('/api/shifts?keyword=早班')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.list.some(s => s.name.includes('早班'))).toBe(true);
    });
  });

  // ========== 获取单个班次 ==========
  describe('GET /api/shifts/:id', () => {
    test('获取班次详情', async () => {
      const res = await request(app)
        .get(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('name', '测试早班');
      expect(res.body.data).toHaveProperty('start_time');
      expect(res.body.data).toHaveProperty('end_time');
    });

    test('获取不存在的班次返回 404', async () => {
      const res = await request(app)
        .get('/api/shifts/99999')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(404);
    });
  });

  // ========== 更新班次 ==========
  describe('PUT /api/shifts/:id', () => {
    test('管理员更新班次', async () => {
      const res = await request(app)
        .put(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: '修改后的早班', color: '#00FF00' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);

      // 验证更新成功
      const getRes = await request(app)
        .get(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(getRes.body.data.name).toBe('修改后的早班');
      expect(getRes.body.data.color).toBe('#00FF00');
    });

    test('员工无权限更新班次', async () => {
      const res = await request(app)
        .put(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ name: '员工修改' });

      expect(res.status).toBe(403);
    });

    test('无可更新字段返回 400', async () => {
      const res = await request(app)
        .put(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({});

      expect(res.status).toBe(400);
    });
  });

  // ========== 删除班次 ==========
  describe('DELETE /api/shifts/:id', () => {
    test('员工无权限删除班次', async () => {
      const res = await request(app)
        .delete(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(403);
    });

    test('管理员删除班次', async () => {
      const res = await request(app)
        .delete(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);

      // 验证已删除
      const getRes = await request(app)
        .get(`/api/shifts/${testShiftId}`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(getRes.status).toBe(404);
    });
  });
});
