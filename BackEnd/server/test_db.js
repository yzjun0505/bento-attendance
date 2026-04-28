const mysql = require('mysql2/promise');
const config = require('./config');
async function test() {
  try {
    console.log('正在用 project_db 测试连接...');
    const conn = await mysql.createConnection({
      host: 'gateway01.us-east-1.prod.aws.tidbcloud.com',
      port: 4000,
      user: '2pzChFU423YkTNK.root',
      password: 'TTd9eYWXHAzBhysi',
      database: 'project_db',
      ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true }
    });
    const [rows] = await conn.execute('SELECT 1 + 1 AS result');
    console.log('✅ TiDB Cloud 连接成功！结果:', rows[0].result);
    await conn.end();
    process.exit(0);
  } catch (err) {
    console.error('❌ TiDB Cloud 连接失败！详细错误:');
    console.error(err);
    process.exit(1);
  }
}
test();
