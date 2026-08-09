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
// Teacher stands in the classroom, app captures GPS. This creates today's
// attendance session for the offering — the date attendance counts against.
router.post('/start', requireTeacherAuth, (req, res) => {
  const { offeringId, latitude, longitude, radiusMeters, durationMinutes } = req.body;

  if (!Number.isInteger(offeringId)) {
    return res.status(400).json({ success: false, message: 'A valid offeringId is required.' });
  }
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return res.status(400).json({ success: false, message: 'Valid latitude/longitude are required.' });
  }

  const offering = db.prepare('SELECT * FROM course_offerings WHERE id = ? AND teacher_id = ?')
    .get(offeringId, req.teacherId);
  if (!offering) {
    return res.status(404).json({ success: false, message: 'Course offering not found or not yours.' });
  }

  const radius = Number.isInteger(radiusMeters) && radiusMeters > 0 ? radiusMeters : 50;
  const duration = Number.isInteger(durationMinutes) && durationMinutes > 0 ? durationMinutes : 60;

  const now = new Date();
  const endsAt = new Date(now.getTime() + duration * 60 * 1000);
  const sessionDate = now.toISOString().slice(0, 10); // YYYY-MM-DD

  const result = db.prepare(`
    INSERT INTO attendance_sessions
      (course_offering_id, session_date, start_time, end_time, latitude, longitude, radius_meters, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(offeringId, sessionDate, now.toISOString(), endsAt.toISOString(), latitude, longitude, radius, now.toISOString());

  return res.json({
    success: true,
    sessionId: result.lastInsertRowid,
    sessionDate,
    endsAt: endsAt.toISOString(),
  });
});

// --- GET /sessions/active?offeringId=... (student) -----------------------------------
router.get('/active', requireAuth, (req, res) => {
  const offeringId = parseInt(req.query.offeringId, 10);
  if (!Number.isInteger(offeringId)) {
    return res.status(400).json({ success: false, message: 'A valid offeringId query param is required.' });
  }

  const now = new Date().toISOString();
  const session = db.prepare(`
    SELECT id, session_date, end_time
    FROM attendance_sessions
    WHERE course_offering_id = ? AND start_time <= ? AND end_time >= ?
    ORDER BY start_time DESC
    LIMIT 1
  `).get(offeringId, now, now);

  if (!session) {
    return res.status(404).json({ success: false, message: 'No active class session for this course right now.' });
  }

  return res.json({
    success: true,
    sessionId: session.id,
    sessionDate: session.session_date,
    endsAt: session.end_time,
  });
});

// --- GET /sessions/by-offering/:offeringId (teacher — list sessions to manage/delete) --
router.get('/by-offering/:offeringId', requireTeacherAuth, (req, res) => {
  const offeringId = parseInt(req.params.offeringId, 10);

  const offering = db.prepare('SELECT id FROM course_offerings WHERE id = ? AND teacher_id = ?')
    .get(offeringId, req.teacherId);
  if (!offering) {
    return res.status(404).json({ success: false, message: 'Offering not found or not yours.' });
  }

  const sessions = db.prepare(`
    SELECT s.id, s.session_date, s.start_time, s.end_time,
           (SELECT COUNT(*) FROM attendance_records ar WHERE ar.session_id = s.id) AS attendance_count
    FROM attendance_sessions s
    WHERE s.course_offering_id = ?
    ORDER BY s.session_date DESC
  `).all(offeringId);

  return res.json({ success: true, sessions });
});

// --- DELETE /sessions/:sessionId (teacher) --------------------------------------------
// Hard delete — removes the session AND every attendance_record tied to it,
// permanently, as requested. This cannot be undone.
router.delete('/:sessionId', requireTeacherAuth, (req, res) => {
  const sessionId = parseInt(req.params.sessionId, 10);

  const session = db.prepare(`
    SELECT s.id FROM attendance_sessions s
    JOIN course_offerings co ON co.id = s.course_offering_id
    WHERE s.id = ? AND co.teacher_id = ?
  `).get(sessionId, req.teacherId);

  if (!session) {
    return res.status(404).json({ success: false, message: 'Session not found or not yours.' });
  }

  const deleteTransaction = db.transaction((id) => {
    db.prepare('DELETE FROM attendance_records WHERE session_id = ?').run(id);
    db.prepare('DELETE FROM attendance_sessions WHERE id = ?').run(id);
  });
  deleteTransaction(sessionId);

  return res.json({ success: true, message: 'Session and its attendance records permanently deleted.' });
});

module.exports = router;