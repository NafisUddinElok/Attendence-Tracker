const db = require('../config/db');
const {
  calculateHaversineDistance,
  calculateCosineSimilarity,
} = require('../utils/securityUtils');

// Geofence + session-length limits a teacher can configure from the app.
// Kept server-side too so a tampered/old client can't push something silly.
const MIN_RADIUS_METERS = 10;
const MAX_RADIUS_METERS = 500;
const MIN_DURATION_MINUTES = 1;
const MAX_DURATION_MINUTES = 180;

// -------------------------------------------------------------
// TEACHER: Start Live Attendance Session (QR removed — geofence only)
// -------------------------------------------------------------
exports.startSession = async (req, res) => {
  const { courseId, title, centerLat, centerLng, radiusMeters, durationMinutes, enableBle } = req.body;
  const teacherId = req.user.id;

  if (!courseId || centerLat === undefined || centerLng === undefined) {
    return res.status(400).json({ message: 'courseId, centerLat, and centerLng are required.' });
  }

  // Validate & clamp teacher-configurable geofence settings
  const radius = Number(radiusMeters) || 50;
  if (radius < MIN_RADIUS_METERS || radius > MAX_RADIUS_METERS) {
    return res.status(400).json({
      message: `radiusMeters must be between ${MIN_RADIUS_METERS} and ${MAX_RADIUS_METERS}.`,
    });
  }

  const duration = Number(durationMinutes) || 15;
  if (duration < MIN_DURATION_MINUTES || duration > MAX_DURATION_MINUTES) {
    return res.status(400).json({
      message: `durationMinutes must be between ${MIN_DURATION_MINUTES} and ${MAX_DURATION_MINUTES}.`,
    });
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

    // 3. Session start (now) + expiry, based on teacher-chosen length.
    //    "session time" (start) is always the moment the teacher taps
    //    Start — there's no future-scheduling here, only how long it
    //    stays open once live.
    const startedAt = new Date();
    const expiresAt = new Date(startedAt.getTime() + duration * 60 * 1000);

    // BLE beacon UUID: generated only if the teacher opted in for this
    // session. Left NULL otherwise, which is what verifyAttendance checks
    // to decide whether BLE proximity is enforced at all.
    const bleUuid = enableBle ? require('crypto').randomUUID() : null;

    const result = await db.query(
      `INSERT INTO attendance_sessions
       (course_id, title, center_lat, center_lng, radius_meters, ble_uuid, expires_at, is_active, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, $8)
       RETURNING *`,
      [
        courseId,
        title || 'Regular Class',
        centerLat,
        centerLng,
        radius,
        bleUuid,
        expiresAt,
        startedAt,
      ]
    );

    const session = result.rows[0];

    res.status(201).json({
      message: 'Live geofenced attendance session started successfully',
      session: {
        id: session.id,
        courseId: session.course_id,
        title: session.title,
        centerLat: parseFloat(session.center_lat),
        centerLng: parseFloat(session.center_lng),
        radiusMeters: session.radius_meters,
        bleUuid: session.ble_uuid,
        startedAt: session.created_at,
        expiresAt: session.expires_at,
        durationMinutes: duration,
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
// STUDENT: Get the currently active session for a course (replaces the
// old QR scan — the student picks a course in the app and we look up
// whatever live session the teacher currently has running for it).
// -------------------------------------------------------------
exports.getActiveSessionForCourse = async (req, res) => {
  const { courseId } = req.params;
  const studentId = req.user.id;

  try {
    // Must be enrolled in the course to see its live session
    const enrollmentCheck = await db.query(
      'SELECT id FROM enrollments WHERE student_id = $1 AND course_id = $2',
      [studentId, courseId]
    );
    if (enrollmentCheck.rows.length === 0) {
      return res.status(403).json({ message: 'You are not enrolled in this course.' });
    }

    const sessionResult = await db.query(
      `SELECT id, title, ble_uuid, expires_at, created_at
       FROM attendance_sessions
       WHERE course_id = $1 AND is_active = TRUE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [courseId]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(404).json({ message: 'No live attendance session right now for this course.' });
    }

    // Already marked? Tell the student up front instead of making them
    // go through face capture first.
    const session = sessionResult.rows[0];
    const dup = await db.query(
      'SELECT id FROM attendance_records WHERE session_id = $1 AND student_id = $2',
      [session.id, studentId]
    );

    return res.status(200).json({
      session: {
        id: session.id,
        title: session.title,
        bleUuid: session.ble_uuid, // null unless the teacher enabled BLE
        expiresAt: session.expires_at,
      },
      alreadyMarked: dup.rows.length > 0,
    });
  } catch (error) {
    console.error('Get Active Session Error:', error);
    res.status(500).json({ message: 'Server error while checking for a live session.' });
  }
};

// -------------------------------------------------------------
// STUDENT: Verify and Mark Attendance (Geofence-based Anti-Proxy Engine)
// Steps: 0) duplicate guard 1) session validity 2) mock-GPS 3) geofence
// 3b) BLE (optional) 4) device binding 5) face match 6) record 7) broadcast
// -------------------------------------------------------------
exports.verifyAttendance = async (req, res) => {
  const {
    sessionId,
    deviceId,
    lat,
    lng,
    isMockLocation,
    livenessPassed,
    faceEmbedding,
    scannedBleUuid,
  } = req.body;

  const studentId = req.user.id;

  try {
    // 0. DUPLICATE ATTENDANCE GUARD FIRST
    const duplicateCheck = await db.query(
      'SELECT id, marked_at FROM attendance_records WHERE session_id = $1 AND student_id = $2',
      [sessionId, studentId]
    );

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        message: 'Attendance already marked for this session. Duplicate submissions are blocked.',
      });
    }

    // 1. SESSION VALIDITY CHECK
    const sessionResult = await db.query(
      'SELECT * FROM attendance_sessions WHERE id = $1',
      [sessionId]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(404).json({ message: 'Attendance session not found.' });
    }

    const session = sessionResult.rows[0];

    if (!session.is_active) {
      return res.status(400).json({ message: 'Attendance session is no longer active.' });
    }

    if (new Date() > new Date(session.expires_at)) {
      return res.status(400).json({ message: 'Attendance session has expired.' });
    }

    // 2. MOCK GPS SPOOF CHECK
    if (isMockLocation === true) {
      return res.status(403).json({
        message: 'Fake GPS / Mock Location detected. Attendance blocked.',
      });
    }

    // 3. GEOFENCE BOUNDARY (HAVERSINE DISTANCE)
    const distanceMeters = calculateHaversineDistance(
      parseFloat(session.center_lat),
      parseFloat(session.center_lng),
      parseFloat(lat),
      parseFloat(lng)
    );

    if (distanceMeters > session.radius_meters) {
      return res.status(400).json({
        message: `You are outside the classroom boundary (${Math.round(distanceMeters)}m away).`,
      });
    }

    // 3b. BLE PROXIMITY CHECK (optional per-session, harder to spoof than GPS)
    // Only enforced when the teacher opted into BLE for this session
    // (session.ble_uuid is set). If the teacher's device couldn't
    // advertise BLE, the session simply has no ble_uuid and this check
    // is skipped — GPS + device + face still all apply.
    if (session.ble_uuid) {
      if (
        !scannedBleUuid ||
        scannedBleUuid.toString().toUpperCase() !== session.ble_uuid.toString().toUpperCase()
      ) {
        try {
          await db.query(
            `INSERT INTO attendance_audit_logs
               (session_id, student_id, device_id, attempted_lat, attempted_lng, is_mock_location, status, failure_reason)
             VALUES ($1, $2, $3, $4, $5, $6, 'FAILED_BLE', 'Teacher Bluetooth beacon not detected nearby')`,
            [sessionId, studentId, deviceId, lat, lng, !!isMockLocation]
          );
        } catch (auditError) {
          console.error('Audit Log Error (non-fatal):', auditError);
        }

        return res.status(403).json({
          message: "Couldn't detect the teacher's Bluetooth beacon nearby. Move closer to the classroom and try again.",
        });
      }
    }

    // 4. HARDWARE DEVICE BINDING
    const studentResult = await db.query(
      'SELECT id, full_name, registration_no, device_id, is_device_locked, face_embedding FROM students WHERE id = $1',
      [studentId]
    );

    if (studentResult.rows.length === 0) {
      return res.status(404).json({ message: 'Student record not found.' });
    }

    const student = studentResult.rows[0];

    if (student.is_device_locked && student.device_id !== deviceId) {
      return res.status(403).json({
        message: 'Device verification failed. You can only give attendance from your registered primary device.',
      });
    }

    // 5. FACE BIOMETRIC EMBEDDING (COSINE SIMILARITY >= 0.75)
    if (!livenessPassed) {
      return res.status(403).json({
        message: 'Liveness check failed. Make sure both eyes are open and you\'re looking straight at the camera, then try again.',
      });
    }

    // Tracked for the audit log (teacher/admin-facing debugging) but never
    // shown to the student directly — a raw similarity percentage is
    // meaningless to them and just invites students to "aim for a number".
    let similarityScore = null;

    if (student.face_embedding && Array.isArray(faceEmbedding)) {
      const registeredEmbedding = typeof student.face_embedding === 'string'
        ? JSON.parse(student.face_embedding)
        : student.face_embedding;

      similarityScore = calculateCosineSimilarity(registeredEmbedding, faceEmbedding);

      if (similarityScore < 0.75) {
        try {
          await db.query(
            `INSERT INTO attendance_audit_logs
               (session_id, student_id, device_id, attempted_lat, attempted_lng, is_mock_location, similarity_score, status, failure_reason)
             VALUES ($1, $2, $3, $4, $5, $6, $7, 'FAILED_FACE', 'Face similarity below threshold')`,
            [sessionId, studentId, deviceId, lat, lng, !!isMockLocation, similarityScore]
          );
        } catch (auditError) {
          console.error('Audit Log Error (non-fatal):', auditError);
        }

        return res.status(403).json({
          message: "Face didn't match your registered profile. Make sure you're in good lighting, remove any mask/sunglasses, and look straight at the camera, then try again.",
        });
      }
    }

    // 6. RECORD ATTENDANCE (attendance_records only has session_id/student_id/status/marked_at)
    const attendanceRecord = await db.query(
      `INSERT INTO attendance_records (session_id, student_id, status)
       VALUES ($1, $2, 'PRESENT')
       RETURNING *`,
      [sessionId, studentId]
    );

    // 6b. AUDIT LOG: keep the full attempt trail (device/location/similarity) separately
    try {
      await db.query(
        `INSERT INTO attendance_audit_logs
           (session_id, student_id, device_id, attempted_lat, attempted_lng, is_mock_location, similarity_score, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'SUCCESS')`,
        [sessionId, studentId, deviceId, lat, lng, !!isMockLocation, similarityScore]
      );
    } catch (auditError) {
      console.error('Audit Log Error (non-fatal):', auditError);
    }

    // 7. REAL-TIME WEBSOCKET BROADCAST TO TEACHER DASHBOARD
    if (req.io) {
      req.io.to(`session_${sessionId}`).emit('student_marked', {
        studentId: student.id,
        studentName: student.full_name,
        regNo: student.registration_no,
        markedAt: attendanceRecord.rows[0].marked_at,
      });
    }

    res.status(200).json({
      message: 'Attendance verified and marked successfully!',
      attendance: attendanceRecord.rows[0],
    });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(400).json({ message: 'Attendance already recorded for this session.' });
    }
    console.error('Verify Attendance Error:', error);
    res.status(500).json({ message: 'Server error during attendance verification.' });
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