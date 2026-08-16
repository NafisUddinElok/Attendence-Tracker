// =====================================================================
// Attendance service - unified 4-check attendance verification.
// =====================================================================
// Phase 6: removes QR + liveness checks. Keeps device + geo + mock +
// face vector. The face vector is sourced from the encrypted-at-rest
// canonical embedding bound at enrolment.
// =====================================================================

const repo = require('./attendance.repo');
const biometricsSvc = require('../biometrics/biometrics.service');
const { calculateHaversineDistance } = require('../../utils/securityUtils');
const { AppError } = require('../../errors/AppError');
const env = require('../../config/env');

const DEFAULT_RADIUS_M = env.GEO_RADIUS_METERS;

async function assertSessionLive(sessionId) {
  if (!sessionId) throw new AppError('VALIDATION_FAILED', 'sessionId is required.', 400);
  const session = await repo.findSessionById(sessionId);
  if (!session) throw new AppError('SESSION_INVALID', 'Attendance session not found.', 404);
  if (!session.is_active) throw new AppError('SESSION_ENDED', 'Session is no longer active.', 400);
  if (new Date() > new Date(session.expires_at)) {
    throw new AppError('SESSION_EXPIRED', 'Session has expired.', 400);
  }
  return session;
}

async function assertFreshAttendance(sessionId, studentId) {
  const dup = await repo.findExistingAttendance(sessionId, studentId);
  if (dup) {
    throw new AppError(
      'ATTENDANCE_ALREADY_MARKED',
      'Attendance already recorded for this session.',
      400,
      { existingId: dup.id, markedAt: dup.marked_at },
    );
  }
  const student = await repo.findStudentById(studentId);
  if (!student) throw new AppError('NOT_FOUND', 'Student record not found.', 404);
  if (!student.is_active) throw new AppError('INACTIVE_ACCOUNT', 'Account is inactive.', 403);
  return student;
}

function checkDeviceBinding(student, deviceId) {
  if (!deviceId) throw new AppError('DEVICE_REQUIRED', 'deviceId is required.', 400);
  if (student.is_device_locked) {
    if (!student.device_id) {
      throw new AppError('FACE_NOT_ENROLLED', 'Device binding incomplete. Re-enrol your face.', 400);
    }
    if (student.device_id !== deviceId) {
      throw new AppError(
        'DEVICE_MISMATCH',
        'You can only give attendance from your registered device.',
        403,
      );
    }
  }
}

function checkMockLocation(isMockLocation) {
  if (isMockLocation === true) {
    throw new AppError(
      'MOCK_LOCATION_DETECTED',
      'Mock / fake GPS detected. Attendance blocked.',
      403,
    );
  }
}

function checkGeofence(session, lat, lng) {
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    throw new AppError('VALIDATION_FAILED', 'lat/lng are required numbers.', 400);
  }
  const radius = session.radius_meters || DEFAULT_RADIUS_M;
  const distance = calculateHaversineDistance(
    parseFloat(session.center_lat),
    parseFloat(session.center_lng),
    lat, lng,
  );
  if (distance > radius) {
    throw new AppError(
      'LOCATION_OUT_OF_RANGE',
      'Outside classroom boundary (' + Math.round(distance) + 'm away, max ' + radius + 'm).',
      400,
      { distanceMeters: distance, radiusMeters: radius },
    );
  }
  return distance;
}

async function checkFaceSim(student, faceEmbedding) {
  const v = await biometricsSvc.verifyFace(student.id, faceEmbedding);
  if (!v.passed) {
    throw new AppError(
      'FACE_MISMATCH',
      'Face mismatch (similarity ' + (v.similarity * 100).toFixed(1) + '%, threshold ' + (v.threshold * 100).toFixed(1) + '%).',
      403,
      { similarity: v.similarity, threshold: v.threshold },
    );
  }
  return v.similarity;
}

exports.markAttendance = async (input) => {
  const { sessionId, studentId, deviceId, lat, lng, isMockLocation, faceEmbedding, io } = input;

  const session = await assertSessionLive(sessionId);
  const student = await assertFreshAttendance(sessionId, studentId);

  checkDeviceBinding(student, deviceId);
  checkMockLocation(isMockLocation);
  checkGeofence(session, lat, lng);
  const similarity = await checkFaceSim(student, faceEmbedding);

  const record = await repo.insertAttendanceRecord({
    sessionId, studentId, deviceId, similarity, isMockLocation,
  });

  try {
    await repo.insertAuditLog({
      sessionId, studentId, deviceId, lat, lng, isMockLocation, similarity,
      status: 'SUCCESS',
    });
  } catch (_auditErr) { /* non-fatal */ }

  if (io && typeof io.to === 'function') {
    io.to('session_' + sessionId).emit('student_marked', {
      studentId: student.id,
      studentName: student.full_name,
      regNo: student.registration_no,
      markedAt: record.marked_at,
    });
  }

  return { attendance: record, similarity };
};

module.exports = {
  markAttendance: exports.markAttendance,
  _assertSessionLive: assertSessionLive,
  _assertFreshAttendance: assertFreshAttendance,
  _checkDeviceBinding: checkDeviceBinding,
  _checkMockLocation: checkMockLocation,
  _checkGeofence: checkGeofence,
  _checkFaceSim: checkFaceSim,
};
