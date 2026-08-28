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