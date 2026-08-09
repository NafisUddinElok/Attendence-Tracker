// database/addTeachers.js
//
// Usage:
//   node database/addTeachers.js TCH001 "Dr. Rahman" mypassword123

const bcrypt = require('bcryptjs');
const db = require('./db');

const [, , teacherCode, name, password] = process.argv;

if (!teacherCode || !name || !password) {
  console.error('Usage: node database/addTeachers.js <teacherCode> "<name>" <password>');
  process.exit(1);
}

const hash = bcrypt.hashSync(password, 10);

db.prepare(`
  INSERT INTO teachers (teacher_code, name, password_hash)
  VALUES (?, ?, ?)
  ON CONFLICT(teacher_code) DO UPDATE SET name = excluded.name, password_hash = excluded.password_hash
`).run(teacherCode, name, hash);

console.log(`Added/updated teacher: ${teacherCode} (${name})`);