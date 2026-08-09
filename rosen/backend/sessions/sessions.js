// backend/sessions/sessions.js
const express = require('express');
const db = require('../database/db');
const { requireAuth, requireTeacherAuth } = require('../auth');

const router = express.Router();

function isValidLatitude(v) {
  return typeof v === 'number' && Number.isFinite(v) && v >= -90 && v <= 90;
}
function isValidLongitude(v) {
  return typeof v === 'number' && Number.isFinite(v) && v >= -180 && v <= 180;
}

// --- POST /sessions/start (teacher) -----------------------------------------------
// Teacher stands in the classroom, app captures GPS, this becomes the geofence
// center for the session.
router.post('/start', requireTeacherAuth, (req, res) => {
  const { courseId, latitude, longitude, radiusMeters, durationMinutes } = req.body;

  if (!Number.isInteger(courseId)) {
    return res.status(400).json({ success: false, message: 'A valid courseId is required.' });
  }
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return res.status(400).json({ success: false, message: 'Valid latitude/longitude are required.' });
  }

  const course = db.prepare('SELECT * FROM courses WHERE id = ? AND teacher_id = ?')
    .get(courseId, req.teacherId);
  if (!course) {
    return res.status(404).json({ success: false, message: 'Course not found or not yours.' });
  }

  const radius = Number.isInteger(radiusMeters) && radiusMeters > 0 ? radiusMeters : 50;
  const duration = Number.isInteger(durationMinutes) && durationMinutes > 0 ? durationMinutes : 60;

  const now = new Date();
  const endsAt = new Date(now.getTime() + duration * 60 * 1000);

  const result = db.prepare(`
    INSERT INTO class_sessions (label, course_id, starts_at, ends_at, latitude, longitude, radius_meters)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    `${course.course_name} — ${now.toLocaleString()}`,
    courseId,
    now.toISOString(),
    endsAt.toISOString(),
    latitude,
    longitude,
    radius
  );

  return res.json({
    success: true,
    sessionId: result.lastInsertRowid,
    endsAt: endsAt.toISOString(),
  });
});

// --- GET /sessions/active?courseId=... (student) -----------------------------------
// Lets the student app find the sessionId to submit attendance for, without
// needing to know it in advance.
router.get('/active', requireAuth, (req, res) => {
  const courseId = parseInt(req.query.courseId, 10);
  if (!Number.isInteger(courseId)) {
    return res.status(400).json({ success: false, message: 'A valid courseId query param is required.' });
  }

  const now = new Date().toISOString();
  const session = db.prepare(`
    SELECT id, label, ends_at
    FROM class_sessions
    WHERE course_id = ? AND starts_at <= ? AND ends_at >= ?
    ORDER BY starts_at DESC
    LIMIT 1
  `).get(courseId, now, now);

  if (!session) {
    return res.status(404).json({ success: false, message: 'No active class session for this course right now.' });
  }

  return res.json({
    success: true,
    sessionId: session.id,
    label: session.label,
    endsAt: session.ends_at,
  });
});

module.exports = router;