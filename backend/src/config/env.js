const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

function optEnv(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === null || String(v).trim() === '' ? fallback : String(v);
}

function reqEnv(name) {
  const v = optEnv(name);
  if (v === undefined) throw new Error(`Missing required env var: ${name}`);
  return v;
}

// In tests we don't want env validation to block the suite.
const TESTING = process.env.NODE_ENV === 'test' || !!process.env.NODE_TEST_CONTEXT;
const defaults = {
  JWT_ACCESS_SECRET: TESTING ? 'test-access-secret' : undefined,
  DB_USER: TESTING ? 'test' : undefined,
  DB_HOST: TESTING ? 'localhost' : undefined,
  DB_NAME: TESTING ? 'test' : undefined,
  DB_PASSWORD: TESTING ? '' : undefined,
};

const env = {
  NODE_ENV: optEnv('NODE_ENV', 'development'),
  PORT: Number(optEnv('PORT', 5000)),

  JWT_ACCESS_SECRET: reqEnv('JWT_ACCESS_SECRET') || defaults.JWT_ACCESS_SECRET,
  JWT_ACCESS_TTL: optEnv('JWT_ACCESS_TTL', '15m'),
  REFRESH_TTL_DAYS: Number(optEnv('REFRESH_TTL_DAYS', 14)),

  DB_USER: reqEnv('DB_USER') || defaults.DB_USER,
  DB_PASSWORD: optEnv('DB_PASSWORD', defaults.DB_PASSWORD),
  DB_HOST: reqEnv('DB_HOST') || defaults.DB_HOST,
  DB_PORT: Number(optEnv('DB_PORT', 5432)),
  DB_NAME: reqEnv('DB_NAME') || defaults.DB_NAME,

  // Render-style: a single connection string. When set, db.js prefers this
  // over the individual DB_* vars. SSL is on by default when this is present.
  DATABASE_URL: optEnv('DATABASE_URL', ''),
  // 'enable' / 'disable'. For local Postgres without SSL keep it 'disable'.
  DB_SSL: optEnv('DB_SSL', 'auto'),

  // Run init.sql + migrations/*.sql on boot (idempotent). Set to '1' on Render
  // so the freshly-provisioned Postgres comes up ready for the API.
  DB_BOOTSTRAP: optEnv('DB_BOOTSTRAP', '0'),

  CORS_ORIGINS: optEnv('CORS_ORIGINS', '*'),
  BCRYPT_COST: Number(optEnv('BCRYPT_COST', 12)),

  // -------------------------------------------------------------
  // Phase 6 — Face / device / geo tuning
  // -------------------------------------------------------------
  // Cosine similarity threshold (0..1). Stored vector vs new capture.
  // 0.55 is permissive; tighten to 0.70 in production.
  FACE_SIM_THRESHOLD: Number(optEnv('FACE_SIM_THRESHOLD', 0.55)),
  // Default geo-fence radius when a session does not specify one.
  GEO_RADIUS_METERS: Number(optEnv('GEO_RADIUS_METERS', 75)),
  // Pepper used by HKDF to derive per-student AES-256 keys from JWT secret.
  // In production this MUST be set to a long random string via env.
  KDF_PEPPER: optEnv('KDF_PEPPER', 'dev-only-change-me-in-production'),
  // Required embedding dimension. The Flutter embedder must produce this.
  FACE_EMBED_DIM: Number(optEnv('FACE_EMBED_DIM', 128)),
};

module.exports = env;
