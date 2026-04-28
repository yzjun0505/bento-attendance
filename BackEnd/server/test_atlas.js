const { MongoClient } = require('mongodb');

// Prefer an environment override so credentials can be rotated without editing code.
const uri = process.env.MONGODB_URI || 'mongodb+srv://db_user:tWmj0b1LU2MInqPF@cluster0.crizeoy.mongodb.net/?appName=Cluster0';
const client = new MongoClient(uri);
async function run() {
  try {
    await client.connect();
    console.log("Connected successfully to Atlas");
    await client.close();
  } catch (e) {
    console.error("Connection failed:", e.message);
    process.exit(1);
  }
}
run();
