// =====================================================================
// Phase 6 integration test: attendance verification.
// =====================================================================
// Stubs biometrics + attendance repos and exercises the 4-check pipeline:
// session-live -> fresh-attendance -> device-bind -> mock-location ->
// geofence -> face-cosine.

require('../_env_setup.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const h = require('./_helpers');

const DIM = 128;

function faceVec(seed) {
  const v = new Array(DIM);
  for (let i = 0; i < DIM; i++) v[i] = Math.sin(seed + i * 0.37);
  let n = 0;
  for (let i = 0; i < DIM; i++) n += v[i] * v[i];
  n = Math.sqrt(n);
  for (let i = 0; i < DIM; i++) v[i] /= n;
  return v;
}

// Three subtly different samples of the same face.
function threeSamples(baseSeed) {
  return [faceVec(baseSeed), faceVec(baseSeed + 0.01), faceVec(baseSeed + 0.02)];
}

// Orthogonal vector for stranger attack (alternating +/-0.9).
function strangerFace() {
  const v = new Array(DIM);
  for (let i = 0; i < DIM; i++) v[i] = i % 2 === 0 ? 0.9 : -0.9;
  let n = 0;
  for (let i = 0; i < DIM; i++) n += v[i] * v[i];
  n = Math.sqrt(n);
  for (let i = 0; i < DIM; i++) v[i] /= n;
  return v;
}

// Build an enrolled student + open session pair. Returns ids needed by tests.
function setup(opts = {}) {
  const bios = h.makeBiometricsRepoStub();
  const att = h.makeAttendanceRepoStub();
  h._setBiosRef(bios);

  const student = h.seedBiometricStudent(bios, {
    id: opts.studentId || 'student-V',
    deviceId: opts.deviceId || 'DEV_OK',
    isDeviceLocked: true,
  });
  const session = h.seedSession(att, {
    id: opts.sessionId || 'session-OK',
    centerLat: 24.9172,
    centerLng: 91.8319,
    radiusMeters: 75,
  });

  h.injectRepoStub('biometrics', bios);
  h.injectRepoStub('attendance', att);

  // Force a fresh service load so it picks up the new stub.
  for (const k of Object.keys(require.cache)) {
    if (k.endsWith('biometrics.service.js') || k.endsWith('attendance.service.js')) {
      delete require.cache[k];
    }
  }

  const svc = require('../../src/modules/attendance/attendance.service');
  const biosSvc = require('../../src/modules/biometrics/biometrics.service');

  return { bios, att, student, session, svc, biosSvc };
}

async function enrollFace(biosSvc, student, deviceId) {
  await biosSvc.enrollFace({
    studentId: student.id,
    deviceId,
    embeddings: threeSamples(7),
  });
}

function input(opts = {}) {
  return {
    sessionId: opts.sessionId || 'session-OK',
    studentId: opts.studentId || 'student-V',
    deviceId: opts.deviceId || 'DEV_OK',
    lat: opts.lat !== undefined ? opts.lat : 24.9172,
    lng: opts.lng !== undefined ? opts.lng : 91.8319,
    isMockLocation: !!opts.isMockLocation,
    faceEmbedding: opts.faceEmbedding || faceVec(7), // same direction as enrolled
    io: undefined,
  };
}

// ---- Tests -----------------------------------------------------------

test('markAttendance: happy path inserts a PRESENT record', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  const result = await ctx.svc.markAttendance(input());

  assert.ok(result.attendance, 'attendance record returned');
  assert.equal(result.attendance.status, 'PRESENT');
  assert.equal(result.attendance.student_id, ctx.student.id);
  assert.equal(result.attendance.session_id, ctx.session.id);
  assert.ok(result.similarity > 0.9, 'high similarity expected');

  // Persisted in stub
  const stored = h.getRecord(ctx.att, ctx.session.id, ctx.student.id);
  assert.ok(stored, 'record should be in stub');
  assert.equal(stored.status, 'PRESENT');
  // Audit log captured
  assert.ok(ctx.att.auditLogs.length >= 1);
  assert.equal(ctx.att.auditLogs[0].status, 'SUCCESS');
});

test('markAttendance: device id mismatch -> DEVICE_MISMATCH', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  await assert.rejects(
    ctx.svc.markAttendance(input({ deviceId: 'DEV_OTHER' })),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'DEVICE_MISMATCH');
      assert.equal(err.status, 403);
      return true;
    },
  );

  // No record persisted
  assert.equal(h.getRecord(ctx.att, ctx.session.id, ctx.student.id), null);
});

test('markAttendance: outside geofence -> LOCATION_OUT_OF_RANGE', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  // ~3.2 km away from (24.9172, 91.8319) -> well outside 75 m radius
  await assert.rejects(
    ctx.svc.markAttendance(input({ lat: 24.9459, lng: 91.8319 })),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'LOCATION_OUT_OF_RANGE');
      assert.equal(err.status, 400);
      assert.ok(err.details && err.details.distanceMeters > 1000);
      return true;
    },
  );
});

test('markAttendance: mock-location flag -> MOCK_LOCATION_DETECTED', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  await assert.rejects(
    ctx.svc.markAttendance(input({ isMockLocation: true })),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'MOCK_LOCATION_DETECTED');
      assert.equal(err.status, 403);
      return true;
    },
  );
});

test('markAttendance: stranger face -> FACE_MISMATCH', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  await assert.rejects(
    ctx.svc.markAttendance(input({ faceEmbedding: strangerFace() })),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'FACE_MISMATCH');
      assert.equal(err.status, 403);
      return true;
    },
  );

  assert.equal(h.getRecord(ctx.att, ctx.session.id, ctx.student.id), null);
});

test('markAttendance: second mark in same session -> ATTENDANCE_ALREADY_MARKED', async () => {
  const ctx = setup();
  await enrollFace(ctx.biosSvc, ctx.student, 'DEV_OK');

  // First mark succeeds.
  const first = await ctx.svc.markAttendance(input());
  assert.ok(first.attendance);

  await assert.rejects(
    ctx.svc.markAttendance(input()),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'ATTENDANCE_ALREADY_MARKED');
      assert.equal(err.status, 400);
      return true;
    },
  );

  // Still exactly one record.
  let count = 0;
  for (const _ of ctx.att.records.values()) count++;
  assert.equal(count, 1);
});

