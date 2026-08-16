// =====================================================================
// Attendance repo — sessions and attendance records lookup.
// =====================================================================

const db = require('../../config/db');

exports.findSessionById = (sessionId) =>
  db.query(
    `SELECT id, course_id, title, center_lat, center_lng, radius_meters,
            totp_secret, expires_at, is_active
       FROM attendance_sessions
      WHERE id = $1
      LIMIT 1`,
    [sessionId],
  ).then((r) => r.rows[0] || null);

exports.findStudentById = (studentId) =>
  db.query(
    `SELECT id, full_name, email, registration_no,
            device_id, is_device_locked, is_active, token_version
       FROM students
      WHERE id = $1
      LIMIT 1`,
    [studentId],
  ).then((r) => r.rows[0] || null);

exports.findExistingAttendance = (sessionId, studentId) =>
  db.query(
    `SELECT id, marked_at
       FROM attendance_records
      WHERE session_id = $1 AND student_id = $2
      LIMIT 1`,
    [sessionId, studentId],
  ).then((r) => r.rows[0] || null);

exports.insertAttendanceRecord = (args) =>
  db.query(
    `INSERT INTO attendance_records
       (session_id, student_id, status, marked_device_id,
        marked_face_similarity, marked_is_mock_location)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, session_id, student_id, status, marked_at`,
    [
      args.sessionId, args.studentId, 'PRESENT',
      args.deviceId, args.similarity, !!args.isMockLocation,
    ],
  ).then((r) => r.rows[0]);

exports.insertAuditLog = (args) =>
  db.query(
    `INSERT INTO attendance_audit_logs
       (session_id, student_id, device_id,
        attempted_lat, attempted_lng, is_mock_location,
        similarity_score, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      args.sessionId, args.studentId, args.deviceId,
      args.lat, args.lng, !!args.isMockLocation,
      args.similarity, args.status,
    ],
  );
