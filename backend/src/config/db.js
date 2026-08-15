const { Pool } = require('pg');
const path = require('path');


// / Explicitly load .env from backend root directory
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });



const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  // Managed Postgres on Render/Railway/etc. requires SSL, but local
  // docker/dev Postgres usually doesn't have a cert configured — so this
  // is opt-in via DB_SSL=true (set it in your cloud provider's env vars)
  // rather than always-on, which would break local development.
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Explicitly test connection on app startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ PostgreSQL Database connection error:', err.message);
  } else {
    console.log('⚡ Connected to PostgreSQL Database');
    release(); // Client release kore pool-e ferat dilam
  }
});

module.exports = {
  query: (text, params) => pool.query(text, params),
};