// db.js
// SQLite persistence layer. Swap this out for Postgres/MongoDB later if you need
// multi-server scaling — the query shapes below will translate directly.

const Database = require('better-sqlite3');
const path = require('path');

// Absolute path, anchored to this file's location — this way the database
// is always the same file no matter which directory you run a script from
// (e.g. `node server.js` from backend/ vs `node addStudents.js` from
// backend/database/ used to silently create two different database files).
const db = new Database(path.join(__dirname, 'attendance.db'));

db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password_hash TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS teachers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password_hash TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS courses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_code TEXT UNIQUE NOT NULL,
    course_name TEXT NOT NULL,
    teacher_id INTEGER NOT NULL,
    FOREIGN KEY (teacher_id) REFERENCES teachers(id)
  );

  CREATE TABLE IF NOT EXISTS student_courses (
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TEXT NOT NULL,
    PRIMARY KEY (student_id, course_id),
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (course_id) REFERENCES courses(id)
  );

  CREATE TABLE IF NOT EXISTS class_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    course_id INTEGER,
    starts_at TEXT NOT NULL,   -- ISO timestamp
    ends_at TEXT NOT NULL,     -- ISO timestamp
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 50,
    FOREIGN KEY (course_id) REFERENCES courses(id)
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

// Safe migration for databases created before course_id existed on sessions.
try {
  db.exec('ALTER TABLE class_sessions ADD COLUMN course_id INTEGER');
} catch (err) {
  // Column already exists — fine, ignore.
}

module.exports = db;