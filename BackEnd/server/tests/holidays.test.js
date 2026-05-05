/**
 * 节假日管理模块接口测试
 * 覆盖：节假日CRUD、批量创建、日期检查
 */
const request = require('supertest');
const { app } = require('../app');

const adminUser = {
  username: 'holidayadmin' + Date.now(),
  password: 'admin123456',
  name: '节假日管理员',
  role: 'admin'
};

const workerUser = {
  username: 'holidayworker' + Date.now(),
  password: 'worker123456',
  name: '节假日员工'
};

let adminToken = null;
let workerToken = null;
let testHolidayId = null;

describe('节假日管理 API 测试', () => {
  beforeAll(async () => {
    const adminReg = await request(app).post('/api/auth/register').send(adminUser);
    const adminLogin = await request(app).post('/api/auth/login').send({
      username: adminUser.username,
      password: adminUser.password
    });
    adminToken = adminLogin.body.data.access_token || adminLogin.body.data.token;

    const workerReg = await request(app).post('/api/auth/register').send(workerUser);
    const workerLogin = await request(app).post('/api/auth/login').send({
      username: workerUser.username,
      password: workerUser.password
    });
    workerToken = workerLogin.body.data.access_token || workerLogin.body.data.token;
  });

  // ========== 创建节假日 ==========
  describe('POST /api/holidays', () => {
    test('管理员创建节假日成功', async () => {
      const res = await request(app)
        .post('/api/holidays')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: '测试国庆节',
          date: '2024-10-01',
          type: 'holiday'
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
      testHolidayId = res.body.data.id;
    });

    test('创建调休上班日', async () => {
      // 使用随机日期避免冲突
      const randomDate = '2024-' + String(Math.floor(Math.random() * 12) + 1).padStart(2, '0') + '-' + String(Math.floor(Math.random() * 28) + 1).padStart(2, '0');
      const res = await request(app)
        .post('/api/holidays')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: '春节调休',
          date: randomDate,
          type: 'workday'
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('缺少必填字段返回 400', async () => {
      const res = await request(app)
        .post('/api/holidays')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: '不完整' });

      expect(res.status).toBe(400);
    });

    test('重复日期返回 400', async () => {
      const res = await request(app)
        .post('/api/holidays')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: '重复日期',
          date: '2024-10-01',
          type: 'holiday'
        });

      expect(res.status).toBe(400);
    });

    test('员工无权限创建', async () => {
      const res = await request(app)
        .post('/api/holidays')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          name: '员工创建',
          date: '2024-12-01',
          type: 'holiday'
        });

      expect(res.status).toBe(403);
    });
  });

  // ========== 批量创建 ==========
  describe('POST /api/holidays/batch', () => {
    test('批量创建节假日', async () => {
      const res = await request(app)
        .post('/api/holidays/batch')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          holidays: [
            { name: '端午节', date: '2024-06-10', type: 'holiday' },
            { name: '中秋节', date: '2024-09-17', type: 'holiday' }
          ]
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('inserted');
    });

    test('空数组返回 400', async () => {
      const res = await request(app)
        .post('/api/holidays/batch')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ holidays: [] });

      expect(res.status).toBe(400);
    });
  });

  // ========== 获取节假日列表 ==========
  describe('GET /api/holidays', () => {
    test('获取所有节假日', async () => {
      const res = await request(app)
        .get('/api/holidays')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('按年份筛选', async () => {
      const res = await request(app)
        .get('/api/holidays?year=2024')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('员工可以查看', async () => {
      const res = await request(app)
        .get('/api/holidays')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
    });
  });

  // ========== 检查日期 ==========
  describe('GET /api/holidays/check', () => {
    test('检查节假日日期', async () => {
      const res = await request(app)
        .get('/api/holidays/check?date=2024-10-01')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data.is_holiday).toBe(true);
      expect(res.body.data.info).toHaveProperty('name');
    });

    test('检查普通工作日', async () => {
      // 2024-03-04 是周一
      const res = await request(app)
        .get('/api/holidays/check?date=2024-03-04')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.is_workday).toBe(true);
    });

    test('检查周末', async () => {
      // 2024-03-02 是周六
      const res = await request(app)
        .get('/api/holidays/check?date=2024-03-02')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.is_holiday).toBe(true);
    });

    test('缺少日期返回 400', async () => {
      const res = await request(app)
        .get('/api/holidays/check')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(400);
    });
  });

  // ========== 更新节假日 ==========
  describe('PUT /api/holidays/:id', () => {
    test('管理员更新节假日', async () => {
      const res = await request(app)
        .put(`/api/holidays/${testHolidayId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: '修改后的国庆节' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('员工无权限更新', async () => {
      const res = await request(app)
        .put(`/api/holidays/${testHolidayId}`)
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ name: '员工修改' });

      expect(res.status).toBe(403);
    });
  });

  // ========== 删除节假日 ==========
  describe('DELETE /api/holidays/:id', () => {
    test('管理员删除节假日', async () => {
      const res = await request(app)
        .delete(`/api/holidays/${testHolidayId}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('员工无权限删除', async () => {
      const res = await request(app)
        .delete('/api/holidays/99999')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(403);
    });
  });
});
