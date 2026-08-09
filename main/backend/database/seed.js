// seed.js
// Run once with `node seed.js` to create a demo student + a live class session
// so you can test /mark-attendance end-to-end.

const bcrypt = require('bcryptjs');
const db = require('./db');

const passwordHash = bcrypt.hashSync('password123', 10);

const insertStudent = db.prepare(`
  INSERT OR IGNORE INTO students (student_code, name, password_hash)
  VALUES (?, ?, ?)
`);
insertStudent.run('STU001', 'Jane Student', passwordHash);

const now = new Date();
const startsAt = new Date(now.getTime() - 5 * 60 * 1000).toISOString();  // started 5 min ago
const endsAt = new Date(now.getTime() + 55 * 60 * 1000).toISOString();  // ends in 55 min

const insertSession = db.prepare(`
  INSERT INTO class_sessions (label, starts_at, ends_at, latitude, longitude, radius_meters)
  VALUES (?, ?, ?, ?, ?, ?)
`);
const result = insertSession.run(
  'CS101 - Morning Lecture',
  startsAt,
  endsAt,
  23.8103,   // <-- replace with your real classroom latitude
  90.4125,   // <-- replace with your real classroom longitude
  50
);

console.log('Seeded demo student: STU001 / password123');
console.log(`Seeded live class session with id ${result.lastInsertRowid}, active until ${endsAt}`);