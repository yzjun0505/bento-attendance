/**
 * 项目模块接口测试
 * 覆盖：创建项目、查询项目、更新项目、删除项目
 */
const request = require('supertest');
const { app } = require('../app');

describe('项目模块 API 测试', () => {
  let token = null;
  let projectId = null;

  // 登录获取 token
  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' });

    if (res.status === 200 && res.body.code === 200) {
      token = res.body.data.access_token;
    }
  });

  describe('POST /api/projects', () => {
    test('创建新项目成功', async () => {
      const res = await request(app)
        .post('/api/projects')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: '测试项目_' + Date.now(),
          address: '北京市测试地址',
          latitude: 39.9042,
          longitude: 116.4074,
          radius: 500,
          description: '这是一个测试项目',
          status: 1
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id');
      projectId = res.body.data.id;
    });

    test('缺少项目名称返回 400', async () => {
      const res = await request(app)
        .post('/api/projects')
        .set('Authorization', `Bearer ${token}`)
        .send({
          address: '没有名字的项目',
          latitude: 39.9042,
          longitude: 116.4074
        });

      expect(res.status).toBe(400);
    });

    test('未登录创建返回 401', async () => {
      const res = await request(app)
        .post('/api/projects')
        .send({ name: '未登录项目' });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/projects', () => {
    test('查询项目列表', async () => {
      const res = await request(app)
        .get('/api/projects?page=1&pageSize=10')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('list');
      expect(res.body.data).toHaveProperty('total');
    });
  });

  describe('GET /api/projects/:id', () => {
    test('查询项目详情', async () => {
      // 确保有项目ID
      if (!projectId) {
        const createRes = await request(app)
          .post('/api/projects')
          .set('Authorization', `Bearer ${token}`)
          .send({
            name: '测试项目_' + Date.now(),
            address: '测试地址',
            latitude: 39.9042,
            longitude: 116.4074,
            radius: 500
          });
        projectId = createRes.body.data?.id;
      }

      const res = await request(app)
        .get(`/api/projects/${projectId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
      expect(res.body.data).toHaveProperty('id', projectId);
    });

    test('查询不存在的项目返回 404', async () => {
      const res = await request(app)
        .get('/api/projects/99999999')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
    });
  });

  describe('PUT /api/projects/:id', () => {
    test('更新项目信息', async () => {
      if (!projectId) return;

      const res = await request(app)
        .put(`/api/projects/${projectId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: '更新后的项目名称',
          description: '更新后的描述'
        });

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });
  });

  describe('DELETE /api/projects/:id', () => {
    test('删除项目', async () => {
      // 创建一个新项目用于删除测试
      const createRes = await request(app)
        .post('/api/projects')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: '待删除项目_' + Date.now(),
          address: '删除测试',
          latitude: 39.9042,
          longitude: 116.4074,
          radius: 500
        });

      const deleteId = createRes.body.data?.id;
      if (!deleteId) return;

      const res = await request(app)
        .delete(`/api/projects/${deleteId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.code).toBe(200);
    });
  });
});
