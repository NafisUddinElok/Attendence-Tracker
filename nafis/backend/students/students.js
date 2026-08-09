// backend/students/students.js
//
// Bulk-add students for a new semester. Passwords are generated here,
// hashed before storage, and returned ONCE in the API response — they are
// never written to a file or logged. The caller (teacher app) is
// responsible for securely relaying each password to its student and must
// not save this response anywhere persistent (no CSV, no git, no chat log).

const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const db = require('../database/db');
const { requireTeacherAuth } = require('../auth');

const router = express.Router();

const PASSWORD_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'; // no 0/O/1/l/I
function generatePassword(length = 8) {
  const bytes = crypto.randomBytes(length);
  let pw = '';
  for (let i = 0; i < length; i++) {
    pw += PASSWORD_CHARS[bytes[i] % PASSWORD_CHARS.length];
  }
  return pw;
}

// --- POST /students/bulk-import (teacher) -----------------------------------------
// body: { students: [{ studentCode, name }, ...], offeringId?: number }
// If offeringId is given, every student (new or already existing) is also
// enrolled in that course offering — handy for adding a whole class roster at once.
router.post('/bulk-import', requireTeacherAuth, (req, res) => {
  const { students, offeringId } = req.body;

  if (!Array.isArray(students) || students.length === 0) {
    return res.status(400).json({ success: false, message: 'A non-empty students array is required.' });
  }
  if (students.length > 300) {
    return res.status(400).json({ success: false, message: 'Max 300 students per import.' });
  }

  let offering = null;
  if (offeringId !== undefined) {
    if (!Number.isInteger(offeringId)) {
      return res.status(400).json({ success: false, message: 'offeringId must be an integer if provided.' });
    }
    offering = db.prepare('SELECT id FROM course_offerings WHERE id = ? AND teacher_id = ?')
      .get(offeringId, req.teacherId);
    if (!offering) {
      return res.status(404).json({ success: false, message: 'Course offering not found or not yours.' });
    }
  }

  const insertStudent = db.prepare('INSERT INTO students (student_code, name, password_hash) VALUES (?, ?, ?)');
  const findStudent = db.prepare('SELECT id FROM students WHERE student_code = ?');
  const enrollStudent = db.prepare(`
    INSERT OR IGNORE INTO enrollments (course_offering_id, student_id, status, enrolled_at)
    VALUES (?, ?, 'enrolled', ?)
  `);

  const results = [];

  for (const entry of students) {
    const studentCode = typeof entry?.studentCode === 'string' ? entry.studentCode.trim() : '';
    const name = typeof entry?.name === 'string' ? entry.name.trim() : '';

    if (!studentCode || !name) {
      results.push({ studentCode: studentCode || '(missing)', name, status: 'error', message: 'studentCode and name are required.' });
      continue;
    }

    const existing = findStudent.get(studentCode);
    let studentId;

    if (existing) {
      studentId = existing.id;
      results.push({ studentCode, name, status: 'already_existed' });
    } else {
      const password = generatePassword();
      const passwordHash = bcrypt.hashSync(password, 10);
      const result = insertStudent.run(studentCode, name, passwordHash);
      studentId = result.lastInsertRowid;
      results.push({ studentCode, name, status: 'created', password });
    }

    if (offering) {
      enrollStudent.run(offering.id, studentId, new Date().toISOString());
    }
  }

  return res.json({ success: true, results });
});

module.exports = router;