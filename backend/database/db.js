// db.js
// SQLite persistence layer. Swap this out for Postgres/MongoDB later if you need
// multi-server scaling — the query shapes below will translate directly.

const Database = require('better-sqlite3');
const db = new Database('attendance.db');

db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password_hash TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS class_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    starts_at TEXT NOT NULL,   -- ISO timestamp
    ends_at TEXT NOT NULL,     -- ISO timestamp
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 50
  );

  CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    session_id INTEGER NOT NULL,
    marked_at TEXT NOT NULL,
    distance_meters REAL NOT NULL,
    face_verified INTEGER NOT NULL DEFAULT 0,
    UNIQUE(student_id, session_id),  -- prevents duplicate marks
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (session_id) REFERENCES class_sessions(id)
  );
`);

// Safe migration for databases created before face_verified existed.
try {
  db.exec('ALTER TABLE attendance ADD COLUMN face_verified INTEGER NOT NULL DEFAULT 0');
} catch (err) {
  // Column already exists — fine, ignore.
}

module.exports = db;