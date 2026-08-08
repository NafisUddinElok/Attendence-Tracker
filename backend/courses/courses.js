// backend/courses/courses.js
const express = require('express');
const db = require('../database/db');
const { requireAuth, requireTeacherAuth } = require('../auth');

const router = express.Router();

// --- POST /courses/create (teacher) ---------------------------------------------
router.post('/create', requireTeacherAuth, (req, res) => {
  const { courseCode, courseName } = req.body;
  if (typeof courseCode !== 'string' || !courseCode.trim()) {
    return res.status(400).json({ success: false, message: 'courseCode is required.' });
  }
  if (typeof courseName !== 'string' || !courseName.trim()) {
    return res.status(400).json({ success: false, message: 'courseName is required.' });
  }

  const existing = db.prepare('SELECT id FROM courses WHERE course_code = ?').get(courseCode.trim());
  if (existing) {
    return res.status(409).json({ success: false, message: 'A course with this code already exists.' });
  }

  const result = db.prepare('INSERT INTO courses (course_code, course_name, teacher_id) VALUES (?, ?, ?)')
    .run(courseCode.trim(), courseName.trim(), req.teacherId);

  return res.json({ success: true, courseId: result.lastInsertRowid });
});

// --- GET /courses/mine (teacher — courses they own) -------------------------------
router.get('/mine', requireTeacherAuth, (req, res) => {
  const courses = db.prepare('SELECT id, course_code, course_name FROM courses WHERE teacher_id = ?')
    .all(req.teacherId);
  return res.json({ success: true, courses });
});

// --- GET /courses/all (student — browse courses to enroll in) ---------------------
router.get('/all', requireAuth, (req, res) => {
  const courses = db.prepare('SELECT id, course_code, course_name FROM courses').all();
  return res.json({ success: true, courses });
});

// --- POST /courses/enroll (student) ----------------------------------------------
router.post('/enroll', requireAuth, (req, res) => {
  const { courseId } = req.body;
  if (!Number.isInteger(courseId)) {
    return res.status(400).json({ success: false, message: 'A valid courseId is required.' });
  }

  const course = db.prepare('SELECT id FROM courses WHERE id = ?').get(courseId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found.' });
  }

  try {
    db.prepare('INSERT INTO student_courses (student_id, course_id, enrolled_at) VALUES (?, ?, ?)')
      .run(req.studentId, courseId, new Date().toISOString());
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_PRIMARYKEY') {
      return res.json({ success: true, message: 'Already enrolled.' });
    }
    throw err;
  }

  return res.json({ success: true, message: 'Enrolled successfully.' });
});

// --- GET /courses/enrolled (student — their own enrolled courses) -----------------
router.get('/enrolled', requireAuth, (req, res) => {
  const courses = db.prepare(`
    SELECT c.id, c.course_code, c.course_name
    FROM courses c
    JOIN student_courses sc ON sc.course_id = c.id
    WHERE sc.student_id = ?
  `).all(req.studentId);
  return res.json({ success: true, courses });
});

// --- GET /courses/:courseId/attendance-export (teacher — CSV download) ------------
router.get('/:courseId/attendance-export', requireTeacherAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);

  const course = db.prepare('SELECT * FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const rows = db.prepare(`
    SELECT s.student_code, s.name, cs.label AS session_label, a.marked_at, a.distance_meters
    FROM attendance a
    JOIN students s ON s.id = a.student_id
    JOIN class_sessions cs ON cs.id = a.session_id
    WHERE cs.course_id = ?
    ORDER BY a.marked_at ASC
  `).all(courseId);

  const header = 'Student Code,Name,Session,Marked At,Distance (m)';
  const lines = rows.map((r) => [
    r.student_code,
    `"${r.name.replace(/"/g, '""')}"`,
    `"${r.session_label.replace(/"/g, '""')}"`,
    r.marked_at,
    Math.round(r.distance_meters),
  ].join(','));

  const csv = [header, ...lines].join('\n');

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="${course.course_code}-attendance.csv"`);
  return res.send(csv);
});

module.exports = router;