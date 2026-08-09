// db.js
// SQLite persistence layer.
//
// Schema shape follows the ER diagram: COURSES (catalog) -> COURSE_OFFERINGS
// (a specific teacher teaching a course in a specific semester) ->
// ENROLLMENTS (students in an offering) -> ATTENDANCE_SESSIONS (one per
// class date) -> ATTENDANCE_RECORDS (one per student per session).
//
// Login stays as-is (separate students/teachers tables, separate
// /login and /teacher-login endpoints) — this schema change is about
// courses/offerings/sessions, not auth.

const Database = require('better-sqlite3');
const path = require('path');

const db = new Database(path.join(__dirname, 'attendance.db'));

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

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

  -- Master catalog of courses (e.g. "CS101 — Intro to Programming").
  -- Not tied to a teacher or semester — that's what course_offerings is for.
  CREATE TABLE IF NOT EXISTS courses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    credit REAL,
    created_at TEXT NOT NULL
  );

  -- A specific teacher teaching a specific course in a specific semester.
  -- This is what students actually enroll in and what sessions belong to.
  CREATE TABLE IF NOT EXISTS course_offerings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    teacher_id INTEGER NOT NULL,
    semester TEXT NOT NULL,          -- e.g. "Spring", "Fall"
    academic_year INTEGER NOT NULL,  -- e.g. 2026
    start_date TEXT,
    end_date TEXT,
    status TEXT NOT NULL DEFAULT 'active',  -- 'active' | 'archived'
    created_at TEXT NOT NULL,
    FOREIGN KEY (course_id) REFERENCES courses(id),
    FOREIGN KEY (teacher_id) REFERENCES teachers(id)
  );

  CREATE TABLE IF NOT EXISTS enrollments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_offering_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'enrolled',  -- 'enrolled' | 'dropped'
    enrolled_at TEXT NOT NULL,
    UNIQUE(course_offering_id, student_id),
    FOREIGN KEY (course_offering_id) REFERENCES course_offerings(id),
    FOREIGN KEY (student_id) REFERENCES students(id)
  );

  -- One row per class date a teacher activates attendance for.
  -- latitude/longitude/radius_meters aren't in the original ER diagram but
  -- are required for the geofencing feature this app already has.
  CREATE TABLE IF NOT EXISTS attendance_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_offering_id INTEGER NOT NULL,
    session_date TEXT NOT NULL,   -- YYYY-MM-DD, the date this session counts for
    start_time TEXT NOT NULL,     -- ISO timestamp, when the window opened
    end_time TEXT NOT NULL,       -- ISO timestamp, when the window closes
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 50,
    created_at TEXT NOT NULL,
    FOREIGN KEY (course_offering_id) REFERENCES course_offerings(id)
  );

  -- One row per student per session they marked attendance for.
  CREATE TABLE IF NOT EXISTS attendance_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'present',       -- 'present' (room to add 'late' etc. later)
    method TEXT NOT NULL DEFAULT 'geofence_face',  -- how attendance was verified
    distance_meters REAL NOT NULL,
    marked_at TEXT NOT NULL,
    UNIQUE(session_id, student_id),  -- prevents duplicate marks
    FOREIGN KEY (session_id) REFERENCES attendance_sessions(id),
    FOREIGN KEY (student_id) REFERENCES students(id)
  );
`);

module.exports = db;