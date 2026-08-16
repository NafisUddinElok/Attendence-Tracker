const { Pool } = require('pg');
const path = require('path');

// / Explicitly load .env from backend root directory
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

// Resolve pool config. Two modes are supported:
//   1) DATABASE_URL present  -> use it directly (Render / Heroku / Supabase).
//                                pg's ConnectionString parses user/host/port/db.
//   2) DATABASE_URL absent   -> use the individual DB_* env vars (local dev).
// SSL: enabled automatically when DATABASE_URL is set (Render requires it).
//      Override with DB_SSL=disable for plain local Postgres.
function buildPoolConfig() {
  const url = process.env.DATABASE_URL;
  if (url && url.trim() !== '') {
    const wantSsl =
      String(process.env.DB_SSL || 'enable').toLowerCase() !== 'disable';
    return {
      connectionString: url,
      ssl: wantSsl ? { rejectUnauthorized: false } : false,
    };
  }
  return {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
    database: process.env.DB_NAME,
    ssl:
      String(process.env.DB_SSL || 'disable').toLowerCase() === 'enable'
        ? { rejectUnauthorized: false }
        : false,
  };
}

const pool = new Pool(buildPoolConfig());

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
  pool,
};