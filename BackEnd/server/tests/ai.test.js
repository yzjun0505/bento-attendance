const request = require('supertest');
const { app } = require('../app');

async function registerAndLogin(user) {
  await request(app).post('/api/auth/register').send(user);
  const res = await request(app).post('/api/auth/login').send({
    username: user.username,
    password: user.password
  });
  return {
    token: res.body.data.access_token || res.body.data.token,
    user: res.body.data.user,
  };
}

describe('AI 助手工具路由测试', () => {
  let adminToken;

  beforeAll(async () => {
    const suffix = Date.now();
    const admin = await registerAndLogin({
      username: `aiadmin${suffix}`,
      password: 'admin123456',
      name: 'AI管理员',
      role: 'admin'
    });
    adminToken = admin.token;
  });

  test('防伪码问题命中防伪码工具', async () => {
    const suffix = Date.now();
    const worker = await registerAndLogin({
      username: `aiwm${suffix}`,
      password: 'worker123456',
      name: 'AI防伪员工',
      role: 'worker'
    });

    const reserveRes = await request(app)
      .get('/api/checkin/reserve-code')
      .set('Authorization', `Bearer ${worker.token}`);
    const code = reserveRes.body.data.watermark_code;
    const dashedCode = `${code.slice(0, 8)}-${code.slice(8)}`.toLowerCase();

    const res = await request(app)
      .post('/api/ai/chat')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ message: `${dashedCode}这个防伪码可以查出来出处吗？` });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
    expect(res.body.data.intent).toBe('watermark');
    expect(res.body.data.result.title).toBe('防伪码查询');
    expect(res.body.data.result.cards.some(card => card.label === '防伪码' && card.value === code)).toBe(true);
  });

  test('轨迹问题命中轨迹工具并返回真实轨迹统计', async () => {
    const suffix = Date.now();
    const workerName = `周周${suffix}`;
    const worker = await registerAndLogin({
      username: `aitrack${suffix}`,
      password: 'worker123456',
      name: workerName,
      role: 'worker'
    });

    await request(app)
      .post('/api/location/report')
      .set('Authorization', `Bearer ${worker.token}`)
      .send({ latitude: 39.9042, longitude: 116.4074, address: '轨迹点1' });
    await request(app)
      .post('/api/location/report')
      .set('Authorization', `Bearer ${worker.token}`)
      .send({ latitude: 39.9050, longitude: 116.4080, address: '轨迹点2' });

    const res = await request(app)
      .post('/api/ai/chat')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ message: `查${workerName}今天轨迹，今天走了多少？` });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
    expect(res.body.data.intent).toBe('track');
    expect(res.body.data.result.title).toContain(workerName);
    expect(res.body.data.result.cards.some(card => card.label === '轨迹点数' && Number(card.value) >= 2)).toBe(true);
  });
});
