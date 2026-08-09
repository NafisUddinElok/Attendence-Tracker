// backend/courses/courses.js
const express = require('express');
const db = require('../database/db');
const { requireAuth, requireTeacherAuth } = require('../auth');

const router = express.Router();

// ============================================================================
// COURSE CATALOG (the "master list" — e.g. "CS101 — Intro to Programming")
// ============================================================================

// --- POST /courses/catalog/create (teacher) --------------------------------
router.post('/catalog/create', requireTeacherAuth, (req, res) => {
  const { courseCode, name, description, credit } = req.body;
  if (typeof courseCode !== 'string' || !courseCode.trim()) {
    return res.status(400).json({ success: false, message: 'courseCode is required.' });
  }
  if (typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ success: false, message: 'name is required.' });
  }

  const existing = db.prepare('SELECT id FROM courses WHERE course_code = ?').get(courseCode.trim());
  if (existing) {
    return res.status(409).json({ success: false, message: 'A course with this code already exists.' });
  }

  const result = db.prepare(`
    INSERT INTO courses (course_code, name, description, credit, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).run(courseCode.trim(), name.trim(), description ?? null, credit ?? null, new Date().toISOString());

  return res.json({ success: true, courseId: result.lastInsertRowid });
});

// --- GET /courses/catalog (anyone logged in — for picking when creating an offering)
router.get('/catalog', requireTeacherAuth, (req, res) => {
  const courses = db.prepare('SELECT id, course_code, name, description, credit FROM courses').all();
  return res.json({ success: true, courses });
});

// ============================================================================
// COURSE OFFERINGS (a teacher teaching a catalog course in a given semester)
// ============================================================================

// --- POST /courses/offerings/create (teacher) -------------------------------
router.post('/offerings/create', requireTeacherAuth, (req, res) => {
  const { courseId, semester, academicYear, startDate, endDate } = req.body;

  if (!Number.isInteger(courseId)) {
    return res.status(400).json({ success: false, message: 'A valid courseId is required.' });
  }
  if (typeof semester !== 'string' || !semester.trim()) {
    return res.status(400).json({ success: false, message: 'semester is required (e.g. "Spring").' });
  }
  if (!Number.isInteger(academicYear)) {
    return res.status(400).json({ success: false, message: 'academicYear is required (e.g. 2026).' });
  }

  const course = db.prepare('SELECT id FROM courses WHERE id = ?').get(courseId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found in catalog.' });
  }

  const result = db.prepare(`
    INSERT INTO course_offerings (course_id, teacher_id, semester, academic_year, start_date, end_date, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, 'active', ?)
  `).run(courseId, req.teacherId, semester.trim(), academicYear, startDate ?? null, endDate ?? null, new Date().toISOString());

  return res.json({ success: true, offeringId: result.lastInsertRowid });
});

const OFFERING_SELECT = `
  SELECT co.id, co.semester, co.academic_year, co.status, co.start_date, co.end_date,
         c.course_code, c.name AS course_name
  FROM course_offerings co
  JOIN courses c ON c.id = co.course_id
`;

// --- GET /courses/offerings/mine (teacher) -----------------------------------
router.get('/offerings/mine', requireTeacherAuth, (req, res) => {
  const offerings = db.prepare(`${OFFERING_SELECT} WHERE co.teacher_id = ? ORDER BY co.created_at DESC`)
    .all(req.teacherId);
  return res.json({ success: true, offerings });
});

// --- GET /courses/offerings/all (student — browse) ---------------------------
router.get('/offerings/all', requireAuth, (req, res) => {
  const offerings = db.prepare(`${OFFERING_SELECT} WHERE co.status = 'active' ORDER BY co.created_at DESC`).all();
  return res.json({ success: true, offerings });
});

// --- GET /courses/offerings/enrolled (student — their own enrollments) -------
router.get('/offerings/enrolled', requireAuth, (req, res) => {
  const offerings = db.prepare(`
    ${OFFERING_SELECT}
    JOIN enrollments e ON e.course_offering_id = co.id
    WHERE e.student_id = ? AND e.status = 'enrolled'
    ORDER BY co.created_at DESC
  `).all(req.studentId);
  return res.json({ success: true, offerings });
});

// --- POST /courses/offerings/enroll (student) ---------------------------------
router.post('/offerings/enroll', requireAuth, (req, res) => {
  const { offeringId } = req.body;
  if (!Number.isInteger(offeringId)) {
    return res.status(400).json({ success: false, message: 'A valid offeringId is required.' });
  }

  const offering = db.prepare('SELECT id FROM course_offerings WHERE id = ?').get(offeringId);
  if (!offering) {
    return res.status(404).json({ success: false, message: 'Course offering not found.' });
  }

  try {
    db.prepare(`
      INSERT INTO enrollments (course_offering_id, student_id, status, enrolled_at)
      VALUES (?, ?, 'enrolled', ?)
    `).run(offeringId, req.studentId, new Date().toISOString());
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      // Already enrolled (or previously dropped) — re-activate if dropped.
      db.prepare(`UPDATE enrollments SET status = 'enrolled' WHERE course_offering_id = ? AND student_id = ?`)
        .run(offeringId, req.studentId);
      return res.json({ success: true, message: 'Enrolled.' });
    }
    throw err;
  }

  return res.json({ success: true, message: 'Enrolled successfully.' });
});

// ============================================================================
// ATTENDANCE — viewing and exporting, scoped to an offering
// ============================================================================

// --- GET /courses/offerings/:offeringId/attendance (teacher — JSON, optional ?date=) --
router.get('/offerings/:offeringId/attendance', requireTeacherAuth, (req, res) => {
  const offeringId = parseInt(req.params.offeringId, 10);
  const dateFilter = req.query.date; // optional YYYY-MM-DD

  const offering = db.prepare('SELECT * FROM course_offerings WHERE id = ? AND teacher_id = ?')
    .get(offeringId, req.teacherId);
  if (!offering) {
    return res.status(404).json({ success: false, message: 'Offering not found or not yours.' });
  }

  let query = `
    SELECT s.student_code, s.name, ases.session_date, ar.status, ar.method, ar.marked_at, ar.distance_meters
    FROM attendance_records ar
    JOIN attendance_sessions ases ON ases.id = ar.session_id
    JOIN students s ON s.id = ar.student_id
    WHERE ases.course_offering_id = ?
  `;
  const params = [offeringId];
  if (dateFilter) {
    query += ' AND ases.session_date = ?';
    params.push(dateFilter);
  }
  query += ' ORDER BY ar.marked_at ASC';

  const records = db.prepare(query).all(...params);
  return res.json({ success: true, records });
});

// --- GET /courses/offerings/:offeringId/my-attendance (student) ----------------
router.get('/offerings/:offeringId/my-attendance', requireAuth, (req, res) => {
  const offeringId = parseInt(req.params.offeringId, 10);

  const records = db.prepare(`
    SELECT ases.session_date, ar.status, ar.marked_at, ar.distance_meters
    FROM attendance_records ar
    JOIN attendance_sessions ases ON ases.id = ar.session_id
    WHERE ases.course_offering_id = ? AND ar.student_id = ?
    ORDER BY ases.session_date ASC
  `).all(offeringId, req.studentId);

  return res.json({ success: true, records });
});

// --- GET /courses/offerings/:offeringId/attendance-export (teacher — CSV, optional ?date=) --
router.get('/offerings/:offeringId/attendance-export', requireTeacherAuth, (req, res) => {
  const offeringId = parseInt(req.params.offeringId, 10);
  const dateFilter = req.query.date;

  const offering = db.prepare(`
    SELECT co.*, c.course_code FROM course_offerings co JOIN courses c ON c.id = co.course_id
    WHERE co.id = ? AND co.teacher_id = ?
  `).get(offeringId, req.teacherId);
  if (!offering) {
    return res.status(404).json({ success: false, message: 'Offering not found or not yours.' });
  }

  let query = `
    SELECT s.student_code, s.name, ases.session_date, ar.status, ar.marked_at, ar.distance_meters
    FROM attendance_records ar
    JOIN attendance_sessions ases ON ases.id = ar.session_id
    JOIN students s ON s.id = ar.student_id
    WHERE ases.course_offering_id = ?
  `;
  const params = [offeringId];
  if (dateFilter) {
    query += ' AND ases.session_date = ?';
    params.push(dateFilter);
  }
  query += ' ORDER BY ases.session_date ASC, ar.marked_at ASC';

  const rows = db.prepare(query).all(...params);

  const header = 'Student Code,Name,Date,Status,Marked At,Distance (m)';
  const lines = rows.map((r) => [
    r.student_code,
    `"${r.name.replace(/"/g, '""')}"`,
    r.session_date,
    r.status,
    r.marked_at,
    Math.round(r.distance_meters),
  ].join(','));

  const csv = [header, ...lines].join('\n');
  const filenameSuffix = dateFilter ? `-${dateFilter}` : '';

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="${offering.course_code}${filenameSuffix}-attendance.csv"`);
  return res.send(csv);
});

module.exports = router;