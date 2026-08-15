const db = require('../config/db');
const { generateTimeToken } = require('../utils/securityUtils');
const crypto = require('crypto');

// Builds the JSON payload embedded in the rotating QR code.
// Uses the SAME algorithm as securityUtils.generateTimeToken() /
// verifyTimeToken() (backend) and TotpHelper.generateRollingToken() (Flutter),
// so the token the student scans is verifiable by attendanceController.verifyAttendance.
function buildQrPayload(sessionId, totpSecret) {
  return JSON.stringify({
    sessionId,
    token: generateTimeToken(totpSecret),
  });
}

// -------------------------------------------------------------
// 1. Start a live session (GPS geofence + rotating QR/TOTP lock)
// -------------------------------------------------------------
exports.startSession = async (req, res) => {
  try {
    const teacherId = req.user.id;
    const { courseId, latitude, longitude, radiusMeters } = req.body;

    if (!courseId) {
      return res.status(400).json({ success: false, message: 'courseId is required' });
    }

    // Verify the requesting teacher actually owns this course
    const courseCheck = await db.query(
      'SELECT id FROM courses WHERE id = $1 AND teacher_id = $2',
      [courseId, teacherId]
    );
    if (courseCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Course not found or unauthorized.' });
    }

    // Deactivate any previous active session for this course
    await db.query(
      `UPDATE attendance_sessions SET is_active = false WHERE course_id = $1 AND is_active = true`,
      [courseId]
    );

    // Create a fresh live session with its own TOTP secret
    const totpSecret = crypto.randomBytes(20).toString('hex');
    const result = await db.query(
      `INSERT INTO attendance_sessions
         (course_id, center_lat, center_lng, radius_meters, totp_secret, is_active)
       VALUES ($1, $2, $3, $4, $5, true)
       RETURNING *`,
      [
        courseId,
        latitude ?? 24.9172,
        longitude ?? 91.8319,
        radiusMeters || 100,
        totpSecret,
      ]
    );

    const session = result.rows[0];
    const qrToken = buildQrPayload(session.id, session.totp_secret);

    return res.status(201).json({
      success: true,
      message: 'Live session started successfully',
      session,
      qrToken,
    });
  } catch (error) {
    console.error('Error starting session:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to start session',
      error: error.message,
    });
  }
};

// -------------------------------------------------------------
// 2. Return the current 15-second rotating QR token
// -------------------------------------------------------------
exports.getDynamicQrToken = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const sessionRes = await db.query(
      `SELECT id, totp_secret FROM attendance_sessions WHERE id = $1 AND is_active = true`,
      [sessionId]
    );

    if (sessionRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Active session not found or ended' });
    }

    const session = sessionRes.rows[0];
    const qrToken = buildQrPayload(session.id, session.totp_secret);

    return res.status(200).json({
      success: true,
      qrToken,
    });
  } catch (error) {
    console.error('Error getting dynamic QR token:', error);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// -------------------------------------------------------------
// 3. End a session
// -------------------------------------------------------------
exports.endSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const teacherId = req.user.id;

    const result = await db.query(
      `UPDATE attendance_sessions s
       SET is_active = false
       FROM courses c
       WHERE s.id = $1 AND s.course_id = c.id AND c.teacher_id = $2
       RETURNING s.id`,
      [sessionId, teacherId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Session not found or unauthorized.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Session ended successfully',
    });
  } catch (error) {
    console.error('Error ending session:', error);
    return res.status(500).json({ success: false, message: 'Failed to end session' });
  }
};
