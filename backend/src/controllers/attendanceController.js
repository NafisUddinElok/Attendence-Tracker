const db = require('../config/db');
const crypto = require('crypto');
const {
  calculateDistanceMeters,
  calculateCosineSimilarity,
  verifyTimeToken,
  generateTimeToken
} = require('../utils/securityUtils');

// Helper to write to attendance_audit_logs table
const logAudit = async ({ sessionId, studentId, deviceId, lat, lng, isMock, score, status, reason }) => {
  try {
    await db.query(
      `INSERT INTO attendance_audit_logs 
       (session_id, student_id, device_id, attempted_lat, attempted_lng, is_mock_location, similarity_score, status, failure_reason)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [sessionId || null, studentId || null, deviceId || null, lat || null, lng || null, isMock || false, score || null, status, reason || null]
    );
  } catch (err) {
    console.error('Audit Logging Error:', err.message);
  }
};

// -------------------------------------------------------------
// 1. TEACHER: Start Attendance Session
// -------------------------------------------------------------
exports.startSession = async (req, res) => {
  const { courseId, centerLat, centerLng, radiusMeters = 50, durationMinutes = 10, title = 'Regular Class', bleUuid } = req.body;
  const teacherId = req.user.id;

  if (!courseId || centerLat === undefined || centerLng === undefined) {
    return res.status(400).json({ message: 'courseId, centerLat, and centerLng are required.' });
  }

  try {
    // 1. Verify Teacher ownership
    const courseCheck = await db.query(
      'SELECT id, course_code, title FROM courses WHERE id = $1 AND teacher_id = $2',
      [courseId, teacherId]
    );
    if (courseCheck.rows.length === 0) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this course.' });
    }

    // 2. Generate Session Security Params
    const totpSecret = crypto.randomBytes(20).toString('hex');
    const generatedBleUuid = bleUuid || crypto.randomUUID();
    const expiresAt = new Date(Date.now() + durationMinutes * 60 * 1000);

    // 3. Create Session in DB
    const sessionRes = await db.query(
      `INSERT INTO attendance_sessions 
       (course_id, session_date, title, center_lat, center_lng, radius_meters, totp_secret, ble_uuid, expires_at, is_active)
       VALUES ($1, CURRENT_DATE, $2, $3, $4, $5, $6, $7, $8, TRUE)
       RETURNING *`,
      [courseId, title, centerLat, centerLng, radiusMeters, totpSecret, generatedBleUuid, expiresAt]
    );

    const session = sessionRes.rows[0];

    res.status(201).json({
      message: 'Attendance session started successfully',
      session: {
        id: session.id,
        courseId: session.course_id,
        title: session.title,
        centerLat: session.center_lat,
        centerLng: session.center_lng,
        radiusMeters: session.radius_meters,
        bleUuid: session.ble_uuid,
        totpSecret: session.totp_secret, // Teacher client uses this to render rolling QR
        expiresAt: session.expires_at,
        isActive: session.is_active,
      }
    });
  } catch (error) {
    console.error('Start Session Error:', error);
    res.status(500).json({ message: 'Server error starting session.' });
  }
};

// -------------------------------------------------------------
// 2. TEACHER: End / Close Active Session
// -------------------------------------------------------------
exports.endSession = async (req, res) => {
  const { sessionId } = req.params;
  const teacherId = req.user.id;

  try {
    const result = await db.query(
      `UPDATE attendance_sessions s
       SET is_active = FALSE
       FROM courses c
       WHERE s.course_id = c.id AND s.id = $1 AND c.teacher_id = $2
       RETURNING s.id, s.title, s.is_active`,
      [sessionId, teacherId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Session not found or unauthorized.' });
    }

    res.status(200).json({ message: 'Attendance session ended.', session: result.rows[0] });
  } catch (error) {
    console.error('End Session Error:', error);
    res.status(500).json({ message: 'Server error ending session.' });
  }
};

// -------------------------------------------------------------
// 3. STUDENT: 5-Step Anti-Proxy Verification & Attendance Submission
// -------------------------------------------------------------
exports.verifyAndMarkAttendance = async (req, res) => {
  const {
    sessionId,
    token,            // Scanned rotating QR token
    deviceId,         // Hardware UUID
    lat,              // Current Student GPS Lat
    lng,              // Current Student GPS Lng
    isMockLocation,   // from Geolocator isMocked flag
    faceEmbedding,    // Float array from ML Kit FaceNet [0.12, -0.45, ...]
    livenessPassed    // Boolean from Active challenge
  } = req.body;

  const studentId = req.user.id;

  if (!sessionId || !token || !deviceId || lat === undefined || lng === undefined) {
    return res.status(400).json({ message: 'Missing required attendance verification fields.' });
  }

  try {
    // ---------------------------------------------------------
    // STEP 1: Fetch Session & Verify Active Status + Expiry
    // ---------------------------------------------------------
    const sessionRes = await db.query('SELECT * FROM attendance_sessions WHERE id = $1', [sessionId]);
    if (sessionRes.rows.length === 0) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_SESSION', reason: 'Session does not exist' });
      return res.status(404).json({ message: 'Attendance session not found.' });
    }

    const session = sessionRes.rows[0];
    const now = new Date();

    if (!session.is_active || new Date(session.expires_at) < now) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_TIME', reason: 'Session expired or closed' });
      return res.status(400).json({ message: 'Attendance session has expired or is inactive.' });
    }

    // ---------------------------------------------------------
    // STEP 2: Check Course Enrollment
    // ---------------------------------------------------------
    const enrollCheck = await db.query(
      'SELECT id FROM enrollments WHERE student_id = $1 AND course_id = $2',
      [studentId, session.course_id]
    );
    if (enrollCheck.rows.length === 0) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_ENROLLMENT', reason: 'Student not enrolled in course' });
      return res.status(403).json({ message: 'You are not enrolled in this course.' });
    }

    // ---------------------------------------------------------
    // STEP 3: Validate 15-Second Dynamic QR Token (Anti-Screenshot)
    // ---------------------------------------------------------
    const isTokenValid = verifyTimeToken(token, session.totp_secret);
    if (!isTokenValid) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_TOKEN', reason: 'QR Code expired or invalid' });
      return res.status(400).json({ message: 'QR Code has expired. Please scan the current live QR code.' });
    }

    // ---------------------------------------------------------
    // STEP 4: Device Binding Check (Anti-Multi-Account)
    // ---------------------------------------------------------
    const studentRes = await db.query('SELECT id, full_name, registration_no, device_id, face_embedding FROM students WHERE id = $1', [studentId]);
    const student = studentRes.rows[0];

    if (!student.device_id) {
      // First time login/attendance: Bind device automatically
      await db.query('UPDATE students SET device_id = $1 WHERE id = $2', [deviceId, studentId]);
    } else if (student.device_id !== deviceId) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_DEVICE', reason: `Device mismatch. Registered: ${student.device_id}, Attempted: ${deviceId}` });
      return res.status(403).json({ message: 'Device verification failed. You can only give attendance from your registered primary device.' });
    }

    // ---------------------------------------------------------
    // STEP 5: Geofence & Anti-Mock GPS Check
    // ---------------------------------------------------------
    if (isMockLocation === true) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: true, status: 'FAILED_MOCK_LOCATION', reason: 'Fake GPS / Mock Provider detected' });
      return res.status(403).json({ message: 'Fake GPS / Mock Location detected. Attendance blocked.' });
    }

    const distance = calculateDistanceMeters(session.center_lat, session.center_lng, lat, lng);
    if (distance > session.radius_meters) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_GEOFENCE', reason: `Out of range. Distance: ${Math.round(distance)}m, Allowed: ${session.radius_meters}m` });
      return res.status(400).json({ message: `You are outside the classroom boundary (${Math.round(distance)}m away).` });
    }

    // ---------------------------------------------------------
    // STEP 6: Face Verification & Liveness Matching
    // ---------------------------------------------------------
    if (!livenessPassed) {
      await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, status: 'FAILED_LIVENESS', reason: 'Failed liveness motion challenge' });
      return res.status(400).json({ message: 'Liveness challenge failed. Please follow the on-screen instructions.' });
    }

    let similarityScore = 1.0;
    if (student.face_embedding && Array.isArray(faceEmbedding)) {
      similarityScore = calculateCosineSimilarity(student.face_embedding, faceEmbedding);
      if (similarityScore < 0.85) { // 85% confidence threshold
        await logAudit({ sessionId, studentId, deviceId, lat, lng, isMock: isMockLocation, score: similarityScore, status: 'FAILED_FACE', reason: `Face mismatch score: ${similarityScore.toFixed(3)}` });
        return res.status(403).json({ message: `Face verification failed (Similarity: ${(similarityScore * 100).toFixed(1)}%).` });
      }
    }

    // ---------------------------------------------------------
    // STEP 7: Mark Attendance in Database
    // ---------------------------------------------------------
    await db.query(
      `INSERT INTO attendance_records (session_id, student_id, status)
       VALUES ($1, $2, 'PRESENT')
       ON CONFLICT (session_id, student_id)
       DO UPDATE SET status = 'PRESENT', marked_at = CURRENT_TIMESTAMP`,
      [sessionId, studentId]
    );

    // Write SUCCESS audit log
    await logAudit({
      sessionId,
      studentId,
      deviceId,
      lat,
      lng,
      isMock: false,
      score: similarityScore,
      status: 'SUCCESS',
      reason: 'All checks passed successfully'
    });

    // Notify Teacher Dashboard via WebSocket if connected
    if (req.io) {
      req.io.to(`session_${sessionId}`).emit('attendance_marked', {
        studentId: student.id,
        fullName: student.full_name,
        registrationNo: student.registration_no,
        markedAt: new Date(),
      });
    }

    res.status(200).json({
      message: 'Attendance verified and marked successfully!',
      status: 'PRESENT',
      similarityScore: (similarityScore * 100).toFixed(1) + '%',
      distanceMeters: Math.round(distance)
    });

  } catch (error) {
    console.error('Attendance Verification Error:', error);
    res.status(500).json({ message: 'Server error during attendance verification.' });
  }
};

// -------------------------------------------------------------
// 4. TEACHER: Live Session Stats
// -------------------------------------------------------------
exports.getSessionLiveStats = async (req, res) => {
  const { sessionId } = req.params;

  try {
    const sessionRes = await db.query('SELECT * FROM attendance_sessions WHERE id = $1', [sessionId]);
    if (sessionRes.rows.length === 0) return res.status(404).json({ message: 'Session not found.' });

    const session = sessionRes.rows[0];

    // Enrolled students vs who marked attendance
    const attendeesRes = await db.query(
      `SELECT s.id, s.full_name, s.registration_no, ar.marked_at, ar.status
       FROM attendance_records ar
       JOIN students s ON ar.student_id = s.id
       WHERE ar.session_id = $1
       ORDER BY ar.marked_at DESC`,
      [sessionId]
    );

    res.status(200).json({
      sessionId: session.id,
      title: session.title,
      isActive: session.is_active,
      expiresAt: session.expires_at,
      totalMarked: attendeesRes.rows.length,
      attendees: attendeesRes.rows,
    });
  } catch (error) {
    console.error('Live Stats Error:', error);
    res.status(500).json({ message: 'Server error fetching live stats.' });
  }
};

// -------------------------------------------------------------
// 5. TEACHER: Download CSV (Existing function kept intact)
// -------------------------------------------------------------
exports.exportAttendanceCSV = async (req, res) => {
  const { courseId } = req.params;
  const teacherId = req.user.id;

  try {
    const courseRes = await db.query('SELECT course_code, title FROM courses WHERE id = $1 AND teacher_id = $2', [courseId, teacherId]);
    if (courseRes.rows.length === 0) return res.status(404).json({ message: 'Course not found or unauthorized.' });
    const course = courseRes.rows[0];

    const sessions = (await db.query(
      `SELECT id, TO_CHAR(session_date, 'YYYY-MM-DD') AS s_date, title FROM attendance_sessions WHERE course_id = $1 ORDER BY session_date ASC, created_at ASC`,
      [courseId]
    )).rows;

    const students = (await db.query(
      `SELECT s.id, s.registration_no, s.full_name FROM enrollments e JOIN students s ON e.student_id = s.id WHERE e.course_id = $1 ORDER BY s.registration_no ASC`,
      [courseId]
    )).rows;

    const records = (await db.query(
      `SELECT ar.session_id, ar.student_id, ar.status FROM attendance_records ar JOIN attendance_sessions asess ON ar.session_id = asess.id WHERE asess.course_id = $1`,
      [courseId]
    )).rows;

    const recordMap = {};
    records.forEach(r => { recordMap[`${r.student_id}_${r.session_id}`] = r.status; });

    let csvHeader = ['Registration No', 'Full Name'];
    sessions.forEach(s => csvHeader.push(`${s.s_date} (${s.title})`));
    csvHeader.push('Present Count', 'Total Classes', 'Attendance %');
    let csvRows = [csvHeader.join(',')];

    students.forEach(student => {
      let presentCount = 0;
      let row = [`"${student.registration_no}"`, `"${student.full_name}"`];

      sessions.forEach(s => {
        const status = recordMap[`${student.id}_${s.id}`] || 'ABSENT';
        if (status === 'PRESENT') presentCount++;
        row.push(status);
      });

      const totalClasses = sessions.length;
      const percentage = totalClasses > 0 ? ((presentCount / totalClasses) * 100).toFixed(1) : 0;
      row.push(presentCount, totalClasses, `${percentage}%`);
      csvRows.push(row.join(','));
    });

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="Attendance_${course.course_code.replace(/\s+/g, '_')}.csv"`);
    return res.status(200).send(csvRows.join('\n'));
  } catch (error) {
    console.error('Export CSV Error:', error);
    res.status(500).json({ message: 'Server error generating CSV.' });
  }
};