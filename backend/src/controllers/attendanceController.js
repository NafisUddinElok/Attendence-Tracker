const db = require('../config/db');
const {
  verifyTimeToken,
  calculateHaversineDistance,
  calculateCosineSimilarity,
  generateTotpSecret,
} = require('../utils/securityUtils');
const attendanceService = require('../modules/attendance/attendance.service');

// -------------------------------------------------------------
// TEACHER: Start Live Attendance Session
// -------------------------------------------------------------
exports.startSession = async (req, res) => {
  const { courseId, title, centerLat, centerLng, radiusMeters, durationMinutes } = req.body;
  const teacherId = req.user.id;

  if (!courseId || centerLat === undefined || centerLng === undefined) {
    return res.status(400).json({ message: 'courseId, centerLat, and centerLng are required.' });
  }

  try {
    // 1. Verify course ownership
    const courseCheck = await db.query(
      'SELECT id, course_code FROM courses WHERE id = $1 AND teacher_id = $2',
      [courseId, teacherId]
    );

    if (courseCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Course not found or unauthorized.' });
    }

    // 2. Deactivate any previous active sessions for this course
    await db.query(
      'UPDATE attendance_sessions SET is_active = FALSE WHERE course_id = $1 AND is_active = TRUE',
      [courseId]
    );

    // 3. Generate unique TOTP secret and session expiry
    const totpSecret = generateTotpSecret();
    const duration = durationMinutes || 15;
    const expiresAt = new Date(Date.now() + duration * 60 * 1000);

    const result = await db.query(
      `INSERT INTO attendance_sessions 
       (course_id, title, center_lat, center_lng, radius_meters, totp_secret, expires_at, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
       RETURNING *`,
      [
        courseId,
        title || 'Regular Class',
        centerLat,
        centerLng,
        radiusMeters || 50,
        totpSecret,
        expiresAt,
      ]
    );

    const session = result.rows[0];

    res.status(201).json({
      message: 'Attendance session started successfully',
      session: {
        id: session.id,
        courseId: session.course_id,
        title: session.title,
        totpSecret: session.totp_secret,
        centerLat: parseFloat(session.center_lat),
        centerLng: parseFloat(session.center_lng),
        radiusMeters: session.radius_meters,
        expiresAt: session.expires_at,
        isActive: session.is_active,
      },
    });
  } catch (error) {
    console.error('Start Session Error:', error);
    res.status(500).json({ message: 'Server error while starting session.' });
  }
};

// -------------------------------------------------------------
// TEACHER: End Session
// -------------------------------------------------------------
exports.endSession = async (req, res) => {
  const { id: sessionId } = req.params;
  const teacherId = req.user.id;

  try {
    const sessionCheck = await db.query(
      `SELECT s.id 
       FROM attendance_sessions s
       JOIN courses c ON s.course_id = c.id
       WHERE s.id = $1 AND c.teacher_id = $2`,
      [sessionId, teacherId]
    );

    if (sessionCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Session not found or unauthorized.' });
    }

    const result = await db.query(
      'UPDATE attendance_sessions SET is_active = FALSE WHERE id = $1 RETURNING id, is_active',
      [sessionId]
    );

    res.status(200).json({
      message: 'Attendance session terminated successfully.',
      session: result.rows[0],
    });
  } catch (error) {
    console.error('End Session Error:', error);
    res.status(500).json({ message: 'Server error ending session.' });
  }
};

// -------------------------------------------------------------
// TEACHER: Get Live Session Stats & Attendees
// -------------------------------------------------------------
exports.getLiveSession = async (req, res) => {
  const { id: sessionId } = req.params;

  try {
    const sessionQuery = await db.query(
      'SELECT id, course_id, title, is_active, expires_at FROM attendance_sessions WHERE id = $1',
      [sessionId]
    );

    if (sessionQuery.rows.length === 0) {
      return res.status(404).json({ message: 'Session not found.' });
    }

    const attendeesQuery = await db.query(
      `SELECT a.id, a.marked_at, s.id AS student_id, s.full_name, s.registration_no, s.department
       FROM attendance_records a
       JOIN students s ON a.student_id = s.id
       WHERE a.session_id = $1
       ORDER BY a.marked_at DESC`,
      [sessionId]
    );

    res.status(200).json({
      session: sessionQuery.rows[0],
      totalMarked: attendeesQuery.rows.length,
      attendees: attendeesQuery.rows,
    });
  } catch (error) {
    console.error('Get Live Session Error:', error);
    res.status(500).json({ message: 'Server error fetching live attendance.' });
  }
};

// -------------------------------------------------------------
// STUDENT: Verify and Mark Attendance (Phase 6 unified engine)
// -------------------------------------------------------------
// Phase 6 removes the QR + liveness checks. The 4-check pipeline
// (device binding + mock-location + geofence + face cosine) lives
// in attendance.service. This handler is now a thin adapter.
exports.verifyAttendance = async (req, res) => {
  const { sessionId, deviceId, lat, lng, isMockLocation, faceEmbedding } = req.body;
  const studentId = req.user.id;

  try {
    const result = await attendanceService.markAttendance({
      sessionId,
      studentId,
      deviceId,
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      isMockLocation: !!isMockLocation,
      faceEmbedding,
      io: req.io,
    });

    res.status(200).json({
      message: 'Attendance verified and marked successfully!',
      attendance: result.attendance,
      similarity: result.similarity,
    });
  } catch (error) {
    // AppError → errorHandler serialises; only log unexpected.
    if (!(error && error.name === 'AppError')) {
      console.error('Verify Attendance Error:', error);
    }
    throw error;
  }
};

// -------------------------------------------------------------
// HISTORY: Get Session History for Course
// -------------------------------------------------------------
exports.getSessionHistory = async (req, res) => {
  const { id: sessionId } = req.params;

  try {
    const result = await db.query(
      `SELECT a.id, a.marked_at, s.full_name, s.registration_no, s.department
       FROM attendance_records a
       JOIN students s ON a.student_id = s.id
       WHERE a.session_id = $1
       ORDER BY a.marked_at ASC`,
      [sessionId]
    );

    res.status(200).json({ attendees: result.rows });
  } catch (error) {
    console.error('Get Session History Error:', error);
    res.status(500).json({ message: 'Server error fetching session history.' });
  }
};

// -------------------------------------------------------------
// HISTORY: Get Student Attendance Log
// -------------------------------------------------------------
exports.getStudentAttendance = async (req, res) => {
  const studentId = req.user.id;

  try {
    const result = await db.query(
      `SELECT a.id, a.marked_at, s.title AS session_title, c.course_code, c.title AS course_title
       FROM attendance_records a
       JOIN attendance_sessions s ON a.session_id = s.id
       JOIN courses c ON s.course_id = c.id
       WHERE a.student_id = $1
       ORDER BY a.marked_at DESC`,
      [studentId]
    );

    res.status(200).json({ attendanceHistory: result.rows });
  } catch (error) {
    console.error('Get Student Attendance Error:', error);
    res.status(500).json({ message: 'Server error fetching student attendance history.' });
  }
};