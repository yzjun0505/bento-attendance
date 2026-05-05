/**
 * 排班管理模块接口测试
 * 覆盖：排班查询、批量排班、日历视图、今日排班
 */
const request = require('supertest');
const { app } = require('../app');

const adminUser = {
  username: 'schedadmin' + Date.now(),
  password: 'admin123456',
  name: '排班管理员',
  role: 'admin'
};

const workerUser = {
  username: 'schedworker' + Date.now(),
  password: 'worker123456',
  name: '排班员工'
};

let adminToken = null;
let workerToken = null;
let workerId = null;
let testShiftId = null;

describe('排班管理 API 测试', () => {
  beforeAll(async () => {
    // 注册管理员
    const adminReg = await request(app).post('/api/auth/register').send(adminUser);
    const adminLogin = await request(app).post('/api/auth/login').send({
      username: adminUser.username,
      password: adminUser.password
    });
    adminToken = adminLogin.body.data.access_token || adminLogin.body.data.token;

    // 注册员工
    const workerReg = await request(app).post('/api/auth/register').send(workerUser);
    workerId = workerReg.body.data.id;
    const workerLogin = await request(app).post('/api/auth/login').send({
      username: workerUser.username,
      password: workerUser.password
    });
    workerToken = workerLogin.body.data.access_token || workerLogin.body.data.token;

    // 创建一个测试班次
    const shiftRes = await request(app)
      .post('/api/shifts')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '测试排班班次',
        start_time: '09:00:00',
        end_time: '18:00:00',
        late_tolerance: 15,
        early_leave_tolerance: 15
      });
    testShiftId = shiftRes.body.data.id;
  });

  // ========== 批量排班 ==========
  describe('POST /api/schedules/batch', () => {
    test('管理员批量排班成功', async () => {
      const today = new Date();
      const dateStr = today.toISOString().slice(0, 10);

      const res = await request(app)
        .post('/api/schedules/batch')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          user_ids: [workerId],
          date_start: dateStr,
          date_end: dateStr,
          shift_id: testShiftId,
          rest_dates: []
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('inserted');
    });

    test('缺少用户ID返回 400', async () => {
      const res = await request(app)
        .post('/api/schedules/batch')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          date_start: '2024-01-01',
          date_end: '2024-01-01',
          shift_id: testShiftId
        });

      expect(res.status).toBe(400);
    });

    test('员工无权限批量排班', async () => {
      const res = await request(app)
        .post('/api/schedules/batch')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          user_ids: [workerId],
          date_start: '2024-01-01',
          date_end: '2024-01-01',
          shift_id: testShiftId
        });

      expect(res.status).toBe(403);
    });
  });

  // ========== 获取排班 ==========
  describe('GET /api/schedules', () => {
    test('管理员获取用户排班', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/schedules?user_id=${workerId}&date_start=${today}&date_end=${today}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('缺少用户ID返回 400', async () => {
      const res = await request(app)
        .get('/api/schedules')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(400);
    });
  });

  // ========== 今日排班（移动端）==========
  describe('GET /api/schedules/today', () => {
    test('员工获取今日排班', async () => {
      const res = await request(app)
        .get('/api/schedules/today')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      // 可能返回排班数据或 null（如果没有排班）
    });

    test('未登录返回 401', async () => {
      const res = await request(app).get('/api/schedules/today');
      expect(res.status).toBe(401);
    });
  });

  // ========== 排班日历 ==========
  describe('GET /api/schedules/calendar', () => {
    test('管理员获取某天排班日历', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .get(`/api/schedules/calendar?date=${today}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    test('缺少日期返回 400', async () => {
      const res = await request(app)
        .get('/api/schedules/calendar')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(400);
    });
  });
});
