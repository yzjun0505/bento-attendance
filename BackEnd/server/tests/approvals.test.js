/**
 * 审批管理模块接口测试（增强版）
 * 覆盖：审批CRUD、审批联动考勤、权限控制
 */
const request = require('supertest');
const { app } = require('../app');

const adminUser = {
  username: 'approvaladmin' + Date.now(),
  password: 'admin123456',
  name: '审批管理员',
  role: 'admin'
};

const workerUser = {
  username: 'approvalworker' + Date.now(),
  password: 'worker123456',
  name: '审批员工'
};

let adminToken = null;
let workerToken = null;
let workerId = null;
let approvalId = null;

describe('审批管理 API 测试', () => {
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
  });

  // ========== 创建审批 ==========
  describe('POST /api/approvals', () => {
    test('员工创建请假申请', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '家中有事',
          start_date: today,
          end_date: today
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
      approvalId = res.body.data.id;
    });

    test('创建补卡申请', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '补卡',
          reason: '忘记打卡',
          start_date: today,
          end_date: today
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('创建加班申请', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const res = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '加班',
          reason: '项目赶进度',
          start_date: today,
          end_date: today
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('缺少必填字段返回 400', async () => {
      const res = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ type: '请假' });

      expect(res.status).toBe(400);
    });

    test('无效类型返回 400', async () => {
      const res = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '无效类型',
          reason: '测试',
          start_date: '2024-01-01'
        });

      expect(res.status).toBe(400);
    });
  });

  // ========== 获取审批列表 ==========
  describe('GET /api/approvals/mine', () => {
    test('员工获取我的申请', async () => {
      const res = await request(app)
        .get('/api/approvals/mine')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('list');
      expect(Array.isArray(res.body.data.list)).toBe(true);
    });
  });

  describe('GET /api/approvals/pending', () => {
    test('管理员获取待审批列表', async () => {
      const res = await request(app)
        .get('/api/approvals/pending')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('list');
    });

    test('员工无权限查看待审批', async () => {
      const res = await request(app)
        .get('/api/approvals/pending')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(403);
    });
  });

  // ========== 审批通过（联动考勤）==========
  describe('PUT /api/approvals/:id/approve', () => {
    test('管理员通过请假申请（联动考勤）', async () => {
      // 先创建一个请假申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '测试联动',
          start_date: today,
          end_date: today
        });
      const leaveApprovalId = createRes.body.data.id;

      const res = await request(app)
        .put(`/api/approvals/${leaveApprovalId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '同意请假' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('管理员通过补卡申请（联动考勤）', async () => {
      // 先创建一个补卡申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '补卡',
          reason: '测试补卡联动',
          start_date: today,
          end_date: today
        });
      const cardApprovalId = createRes.body.data.id;

      const res = await request(app)
        .put(`/api/approvals/${cardApprovalId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '同意补卡' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('重复审批返回 400', async () => {
      // 先创建一个新的待审批申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '测试重复审批',
          start_date: today,
          end_date: today
        });
      const newApprovalId = createRes.body.data.id;

      // 第一次审批通过
      await request(app)
        .put(`/api/approvals/${newApprovalId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '第一次审批' });

      // 第二次审批应该失败
      const res = await request(app)
        .put(`/api/approvals/${newApprovalId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '重复审批' });

      expect(res.status).toBe(400);
    });

    test('审批不存在的申请返回 404', async () => {
      const res = await request(app)
        .put('/api/approvals/99999/approve')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '测试' });

      expect(res.status).toBe(404);
    });

    test('员工无权限审批', async () => {
      const res = await request(app)
        .put(`/api/approvals/${approvalId}/approve`)
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ remark: '员工审批' });

      expect(res.status).toBe(403);
    });
  });

  // ========== 审批驳回 ==========
  describe('PUT /api/approvals/:id/reject', () => {
    test('管理员驳回申请', async () => {
      // 先创建一个新申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '测试驳回',
          start_date: today,
          end_date: today
        });
      const rejectId = createRes.body.data.id;

      const res = await request(app)
        .put(`/api/approvals/${rejectId}/reject`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '理由不充分' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('员工无权限驳回', async () => {
      const res = await request(app)
        .put(`/api/approvals/${approvalId}/reject`)
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ remark: '员工驳回' });

      expect(res.status).toBe(403);
    });
  });

  // ========== 删除审批 ==========
  describe('DELETE /api/approvals/:id', () => {
    test('员工删除自己的待审批申请', async () => {
      // 先创建一个新申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '测试删除',
          start_date: today,
          end_date: today
        });
      const deleteId = createRes.body.data.id;

      const res = await request(app)
        .delete(`/api/approvals/${deleteId}`)
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });

    test('删除已处理的审批返回 400', async () => {
      // 先创建并审批一个申请
      const today = new Date().toISOString().slice(0, 10);
      const createRes = await request(app)
        .post('/api/approvals')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({
          type: '请假',
          reason: '测试删除已处理',
          start_date: today,
          end_date: today
        });
      const processedId = createRes.body.data.id;

      // 管理员审批通过
      await request(app)
        .put(`/api/approvals/${processedId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ remark: '同意' });

      // 尝试删除已处理的审批
      const res = await request(app)
        .delete(`/api/approvals/${processedId}`)
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(400);
    });

    test('删除不存在的审批返回 404', async () => {
      const res = await request(app)
        .delete('/api/approvals/99999')
        .set('Authorization', `Bearer ${workerToken}`);

      expect(res.status).toBe(404);
    });
  });
});
