const mysql = require('mysql2/promise');
require('dotenv').config(); // db.js 자체에서도 환경 변수를 로드하도록 추가

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  user: process.env.DB_USER || 'root',      // 만약 .env를 못 읽으면 'root' 사용
  password: process.env.DB_PASSWORD || '1234', // 설정하신 비번 '1234' 사용
  database: process.env.DB_NAME || 'galrae',
  port: process.env.DB_PORT || 3307,        // 아까 설정한 포트 3307 사용
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

module.exports = pool;