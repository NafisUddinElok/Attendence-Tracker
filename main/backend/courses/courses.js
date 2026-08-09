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

// --- GET /courses/:courseId/students (teacher — full roster) ---------------------
// Returns every student enrolled in one of the teacher's own courses.
// Search-by-name is done client-side in the app (roster sizes are small
// enough — max 300 per bulk import — that a local filter is instant and
// avoids a network round-trip per keystroke).
router.get('/:courseId/students', requireTeacherAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);

  const course = db.prepare('SELECT id FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const students = db.prepare(`
    SELECT s.id, s.student_code, s.name, sc.enrolled_at
    FROM student_courses sc
    JOIN students s ON s.id = sc.student_id
    WHERE sc.course_id = ?
    ORDER BY s.name COLLATE NOCASE ASC
  `).all(courseId);

  return res.json({ success: true, students });
});

// --- GET /courses/:courseId/students-export (teacher — roster CSV download) -------
router.get('/:courseId/students-export', requireTeacherAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);

  const course = db.prepare('SELECT * FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const rows = db.prepare(`
    SELECT s.student_code, s.name, sc.enrolled_at
    FROM student_courses sc
    JOIN students s ON s.id = sc.student_id
    WHERE sc.course_id = ?
    ORDER BY s.name COLLATE NOCASE ASC
  `).all(courseId);

  const header = 'Student Code,Name,Enrolled At';
  const lines = rows.map((r) => [
    r.student_code,
    `"${r.name.replace(/"/g, '""')}"`,
    r.enrolled_at,
  ].join(','));

  const csv = [header, ...lines].join('\n');

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="${course.course_code}-roster.csv"`);
  return res.send(csv);
});

// --- DELETE /courses/:courseId/students/:studentId (teacher — unenroll) -----------
// Removes the enrollment row only — the student account itself, and any
// attendance history they already have (in this or other courses), is left
// untouched. This is "remove from this course's roster", not "delete this
// student's account" — those are deliberately different actions; wiring an
// actual account-delete button up to this route would be a real bug.
router.delete('/:courseId/students/:studentId', requireTeacherAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);
  const studentId = parseInt(req.params.studentId, 10);

  const course = db.prepare('SELECT id FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const result = db.prepare('DELETE FROM student_courses WHERE course_id = ? AND student_id = ?')
    .run(courseId, studentId);

  if (result.changes === 0) {
    return res.status(404).json({ success: false, message: 'That student is not enrolled in this course.' });
  }

  return res.json({ success: true, message: 'Student removed from course.' });
});

// --- GET /courses/mine (teacher — courses they own) -------------------------------
router.get('/mine', requireTeacherAuth, (req, res) => {
  const courses = db.prepare('SELECT id, course_code, course_name FROM courses WHERE teacher_id = ?')
    .all(req.teacherId);
  return res.json({ success: true, courses });
});

// --- POST /courses/join (student — enroll by typing the course's code) ------------
// Primary enroll path: teacher tells students the courseCode (they set it
// themselves at creation, e.g. "CS101"), student types it here instead of
// browsing every course in the system. Case/whitespace-insensitive so
// "cs101", " CS101 ", and "CS101" all resolve to the same course.
router.post('/join', requireAuth, (req, res) => {
  const { courseCode } = req.body;
  if (typeof courseCode !== 'string' || !courseCode.trim()) {
    return res.status(400).json({ success: false, message: 'courseCode is required.' });
  }

  const course = db.prepare('SELECT id, course_code, course_name FROM courses WHERE UPPER(course_code) = UPPER(?)')
    .get(courseCode.trim());
  if (!course) {
    return res.status(404).json({ success: false, message: 'No course found with that code. Double-check it with your teacher.' });
  }

  try {
    db.prepare('INSERT INTO student_courses (student_id, course_id, enrolled_at) VALUES (?, ?, ?)')
      .run(req.studentId, course.id, new Date().toISOString());
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_PRIMARYKEY') {
      return res.json({
        success: true,
        message: 'You were already enrolled in this course.',
        courseId: course.id,
        courseName: course.course_name,
      });
    }
    throw err;
  }

  return res.json({
    success: true,
    message: 'Enrolled successfully.',
    courseId: course.id,
    courseName: course.course_name,
  });
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

// --- GET /courses/:courseId/attendance (teacher — JSON, for in-app table) ---------
// Same underlying data as the CSV export below, just as JSON so the Flutter
// app can render a table without parsing CSV on-device.
router.get('/:courseId/attendance', requireTeacherAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);

  const course = db.prepare('SELECT * FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const records = db.prepare(`
    SELECT s.student_code, s.name, cs.label AS session_label, a.marked_at, a.distance_meters
    FROM attendance a
    JOIN students s ON s.id = a.student_id
    JOIN class_sessions cs ON cs.id = a.session_id
    WHERE cs.course_id = ?
    ORDER BY a.marked_at DESC
  `).all(courseId);

  return res.json({ success: true, courseName: course.course_name, records });
});

// --- GET /courses/:courseId/my-attendance (student — their own records) -----------
// Lets a student see which sessions they've been marked present for in a
// course they're enrolled in. Scoped to req.studentId — a student can only
// ever see their own attendance, never another student's.
router.get('/:courseId/my-attendance', requireAuth, (req, res) => {
  const courseId = parseInt(req.params.courseId, 10);

  const enrolled = db.prepare('SELECT 1 FROM student_courses WHERE student_id = ? AND course_id = ?')
    .get(req.studentId, courseId);
  if (!enrolled) {
    return res.status(404).json({ success: false, message: 'You are not enrolled in this course.' });
  }

  const records = db.prepare(`
    SELECT cs.label AS session_label, a.marked_at, a.distance_meters
    FROM attendance a
    JOIN class_sessions cs ON cs.id = a.session_id
    WHERE cs.course_id = ? AND a.student_id = ?
    ORDER BY a.marked_at DESC
  `).all(courseId, req.studentId);

  return res.json({ success: true, records });
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