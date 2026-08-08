// database/addStudents.js
//
// Add ONE student:
//   node database/addStudents.js STU002 "Rahim Uddin" mypassword123
//
// Add MANY students from a CSV file (no header row), format:
//   studentCode,name,password
//   STU002,Rahim Uddin,pass111
//   STU003,Karim Ahmed,pass222
//
//   node database/addStudents.js --csv students.csv

const fs = require('fs');
const bcrypt = require('bcryptjs');
const db = require('./db');

const insertStudent = db.prepare(`
  INSERT INTO students (student_code, name, password_hash)
  VALUES (?, ?, ?)
  ON CONFLICT(student_code) DO UPDATE SET name = excluded.name, password_hash = excluded.password_hash
`);

function addOne(studentCode, name, password) {
  const hash = bcrypt.hashSync(password, 10);
  insertStudent.run(studentCode, name, hash);
  console.log(`Added/updated: ${studentCode} (${name})`);
}

const args = process.argv.slice(2);

if (args[0] === '--csv') {
  const filePath = args[1];
  if (!filePath) {
    console.error('Usage: node database/addStudents.js --csv <path-to-file.csv>');
    process.exit(1);
  }
  const lines = fs.readFileSync(filePath, 'utf-8').split('\n').map((l) => l.trim()).filter(Boolean);

  for (const line of lines) {
    const [studentCode, name, password] = line.split(',').map((s) => s.trim());
    if (!studentCode || !name || !password) {
      console.warn(`Skipping malformed line: "${line}"`);
      continue;
    }
    addOne(studentCode, name, password);
  }
  console.log(`Done. Processed ${lines.length} line(s).`);
} else {
  const [studentCode, name, password] = args;
  if (!studentCode || !name || !password) {
    console.error('Usage: node database/addStudents.js <studentCode> "<name>" <password>');
    console.error('   or: node database/addStudents.js --csv <path-to-file.csv>');
    process.exit(1);
  }
  addOne(studentCode, name, password);
}