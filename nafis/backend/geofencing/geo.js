// backend/geofencing/geo.js
// Geofencing attendance feature, exposed as an Express Router so it can be
// mounted alongside facialdetection/ and qr/ from the main server.js.

const express = require('express');
const rateLimit = require('express-rate-limit');

const db = require('../database/db');
const { requireAuth } = require('../auth');

const router = express.Router();

// --- Rate limiting -----------------------------------------------------------
const attendanceLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many attempts. Please wait a minute and try again.' },
});

// --- Haversine formula ---------------------------------------------------------
function calculateDistanceInMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const toRadians = (deg) => deg * (Math.PI / 180);

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// --- Input validation ----------------------------------------------------------
function isValidLatitude(v) {
  return typeof v === 'number' && Number.isFinite(v) && v >= -90 && v <= 90;
}
function isValidLongitude(v) {
  return typeof v === 'number' && Number.isFinite(v) && v >= -180 && v <= 180;
}

// --- Route: POST /geofencing/mark-attendance ------------------------------------
router.post('/mark-attendance', attendanceLimiter, requireAuth, (req, res) => {
  const { sessionId, latitude, longitude, isMocked, faceVerified } = req.body;
  const studentId = req.studentId; // from verified JWT — never trust body for this

  if (!Number.isInteger(sessionId)) {
    return res.status(400).json({ success: false, message: 'A valid sessionId is required.' });
  }
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return res.status(400).json({ success: false, message: 'Valid latitude/longitude are required.' });
  }

  // See README.md — isMocked must come from a real native check on the client
  // (Android: Location.isFromMockProvider()), not a hand-set boolean.
  if (isMocked) {
    return res.status(403).json({
      success: false,
      message: 'Fake GPS detected. Please turn off location spoofing.',
    });
  }

  // faceVerified must come from an on-device liveness check (blink detection —
  // see facialdetection/ on the Flutter side) run immediately before this call.
  // Like isMocked, this is a client-reported flag: it stops accidental/careless
  // spoofing (typed booleans, static photos held up to the camera) but a
  // determined attacker with a modified client could still lie about it. If you
  // need stronger guarantees later, send the captured frame to the server and
  // verify it there instead of trusting the client's boolean.
  if (faceVerified !== true) {
    return res.status(403).json({
      success: false,
      message: 'Face verification failed. Please look at the camera and try again.',
    });
  }

  const session = db.prepare('SELECT * FROM attendance_sessions WHERE id = ?').get(sessionId);
  if (!session) {
    return res.status(404).json({ success: false, message: 'Class session not found.' });
  }

  const now = new Date();
  if (now < new Date(session.start_time) || now > new Date(session.end_time)) {
    return res.status(400).json({ success: false, message: 'This class session is not currently active.' });
  }

  const distance = calculateDistanceInMeters(session.latitude, session.longitude, latitude, longitude);

  if (distance > session.radius_meters) {
    console.log(`Failed: student ${studentId} is ${Math.round(distance)}m from session ${sessionId}.`);
    return res.status(400).json({
      success: false,
      message: `You are too far from the classroom (${Math.round(distance)} meters away).`,
    });
  }

  try {
    db.prepare(`
      INSERT INTO attendance_records (session_id, student_id, status, method, distance_meters, marked_at)
      VALUES (?, ?, 'present', 'geofence_face', ?, ?)
    `).run(sessionId, studentId, distance, now.toISOString());
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(409).json({ success: false, message: 'Attendance already marked for this session.' });
    }
    console.error('DB error saving attendance:', err);
    return res.status(500).json({ success: false, message: 'Internal server error.' });
  }

  console.log(`Success: student ${studentId} marked present for session ${sessionId} (${Math.round(distance)}m).`);
  return res.json({ success: true, message: 'Attendance marked successfully!' });
});

module.exports = router;