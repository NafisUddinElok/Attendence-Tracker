// =====================================================================
// Phase 6 integration test: biometrics enrolment.
// =====================================================================
// Stubs the biometrics repo so we can hit the service layer directly
// without a live Postgres.

require('../_env_setup.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const h = require('./_helpers');

const DIM = 128;

// Make a unit-norm face vector with a deterministic seed.
function faceVec(seed) {
  const v = new Array(DIM);
  for (let i = 0; i < DIM; i++) v[i] = Math.sin(seed + i * 0.37);
  let n = 0;
  for (let i = 0; i < DIM; i++) n += v[i] * v[i];
  n = Math.sqrt(n);
  for (let i = 0; i < DIM; i++) v[i] /= n;
  return v;
}

// Three subtly different samples of the same face (multi-angle captures).
function threeSamples(baseSeed) {
  return [faceVec(baseSeed), faceVec(baseSeed + 0.01), faceVec(baseSeed + 0.02)];
}

// Load service fresh per test with the given stubs installed.
function loadService(biosStub, attStub) {
  for (const k of Object.keys(require.cache)) {
    if (k.endsWith('biometrics.service.js') || k.endsWith('attendance.service.js')) {
      delete require.cache[k];
    }
  }
  if (attStub) {
    h._setBiosRef(biosStub);
    h.injectRepoStub('attendance', attStub);
  }
  h.injectRepoStub('biometrics', biosStub);
  return require('../../src/modules/biometrics/biometrics.service');
}

// ---- Tests -----------------------------------------------------------

test('enrollFace: happy path persists encrypted binding and locks device', async () => {
  const bios = h.makeBiometricsRepoStub();
  const student = h.seedBiometricStudent(bios, { id: 'student-A' });
  const svc = loadService(bios, h.makeAttendanceRepoStub());

  const result = await svc.enrollFace({
    studentId: student.id,
    deviceId: 'DEV_AAA',
    embeddings: threeSamples(1),
  });

  assert.equal(result.studentId, student.id);
  assert.equal(result.deviceId, 'DEV_AAA');
  assert.ok(result.faceEnrolledAt, 'faceEnrolledAt should be set');

  const stored = h.getStudent(bios, student.id);
  assert.equal(stored.device_id, 'DEV_AAA');
  assert.equal(stored.is_device_locked, true);
  assert.equal(stored.face_is_encrypted, true);
  assert.ok(stored.face_embedding_encrypted instanceof Buffer);
  assert.ok(stored.face_embedding_iv instanceof Buffer);
  assert.ok(stored.face_embedding_auth_tag instanceof Buffer);
});

test('enrollFace: device already bound to another student -> DEVICE_ALREADY_BOUND', async () => {
  const bios = h.makeBiometricsRepoStub();
  const a = h.seedBiometricStudent(bios, { id: 'student-A' });
  const b = h.seedBiometricStudent(bios, { id: 'student-B' });
  const svc = loadService(bios, h.makeAttendanceRepoStub());

  await svc.enrollFace({
    studentId: a.id,
    deviceId: 'DEV_SHARED',
    embeddings: threeSamples(1),
  });

  await assert.rejects(
    svc.enrollFace({
      studentId: b.id,
      deviceId: 'DEV_SHARED',
      embeddings: threeSamples(7),
    }),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'DEVICE_ALREADY_BOUND');
      assert.equal(err.status, 409);
      return true;
    },
  );
});

test('enrollFace: identical embeddings (degenerate) -> WEAK_FACE', async () => {
  const bios = h.makeBiometricsRepoStub();
  const student = h.seedBiometricStudent(bios, { id: 'student-W' });
  const svc = loadService(bios, h.makeAttendanceRepoStub());

  const identical = [faceVec(42), faceVec(42), faceVec(42)];

  await assert.rejects(
    svc.enrollFace({
      studentId: student.id,
      deviceId: 'DEV_WEAK',
      embeddings: identical,
    }),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'WEAK_FACE');
      assert.equal(err.status, 400);
      return true;
    },
  );
});

test('enrollFace: locked student tries a different device -> DEVICE_LOCKED', async () => {
  const bios = h.makeBiometricsRepoStub();
  const student = h.seedBiometricStudent(bios, {
    id: 'student-L',
    deviceId: 'DEV_LOCKED_1',
    isDeviceLocked: true,
    faceIsEncrypted: true,
  });
  const svc = loadService(bios, h.makeAttendanceRepoStub());

  await assert.rejects(
    svc.enrollFace({
      studentId: student.id,
      deviceId: 'DEV_LOCKED_2',
      embeddings: threeSamples(99),
    }),
    (err) => {
      assert.equal(err.name, 'AppError');
      assert.equal(err.code, 'DEVICE_LOCKED');
      assert.equal(err.status, 403);
      return true;
    },
  );

  const stored = h.getStudent(bios, student.id);
  assert.equal(stored.device_id, 'DEV_LOCKED_1');
});

