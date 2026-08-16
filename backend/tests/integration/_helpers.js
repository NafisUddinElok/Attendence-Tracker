// Lightweight in-memory test fixtures for the auth module.
// We stub the repo so service tests do not require a live Postgres.
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

function hashToken(t) {
  return crypto.createHash('sha256').update(t).digest('hex');
}

function newRefreshToken() {
  return crypto.randomBytes(32).toString('hex');
}

function makeRepoFixture() {
  const students = new Map();
  const teachers = new Map();
  const refreshTokens = new Map();

  return {
    findStudentByEmail: async (email) => students.get(email.toLowerCase()) || null,
    findTeacherByEmail: async (email) => teachers.get(email.toLowerCase()) || null,
    findStudentByRegNo: async (reg) => {
      for (const s of students.values()) if (s.registration_no === reg) return s;
      return null;
    },
    findTeacherByTeacherId: async (tid) => {
      for (const t of teachers.values()) if (t.teacher_id === tid) return t;
      return null;
    },
    insertStudent: async ({ fullName, email, passwordHash, registrationNo, department, session }) => {
      const row = {
        id: crypto.randomUUID(),
        full_name: fullName,
        email: email.toLowerCase(),
        password_hash: passwordHash,
        registration_no: registrationNo,
        department: department || null,
        session: session || null,
        is_active: true,
        token_version: 1,
        last_login_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };
      students.set(row.email, row);
      return row;
    },
    insertTeacher: async ({ fullName, email, passwordHash, teacherId, department, designation }) => {
      const row = {
        id: crypto.randomUUID(),
        full_name: fullName,
        email: email.toLowerCase(),
        password_hash: passwordHash,
        teacher_id: teacherId,
        department: department || null,
        designation: designation || null,
        is_active: true,
        token_version: 1,
        last_login_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      };
      teachers.set(row.email, row);
      return row;
    },
    updateLastLogin: async (_table, _id) => { /* noop */ },
    findById: async (table, id) => {
      const map = table === 'students' ? students : teachers;
      for (const row of map.values()) if (row.id === id) return row;
      return null;
    },
    insertRefreshToken: async ({ userId, role, tokenHash, expiresAt, userAgent, ip }) => {
      const id = crypto.randomUUID();
      refreshTokens.set(tokenHash, {
        id, user_id: userId, role, token_hash: tokenHash,
        parent_id: null, replaced_by_id: null,
        expires_at: expiresAt,
        revoked_at: null,
        user_agent: userAgent || null,
        ip: ip || null,
        created_at: new Date(),
      });
      return { id, expires_at: expiresAt };
    },
    findActiveRefresh: async (tokenHash) => {
      const r = refreshTokens.get(tokenHash);
      if (!r) return null;
      if (r.revoked_at) return null;
      if (r.expires_at <= new Date()) return null;
      return r;
    },
    revokeRefresh: async (id) => {
      for (const r of refreshTokens.values()) {
        if (r.id === id) { r.revoked_at = new Date(); return; }
      }
    },
    markReplaced: async (oldId, replacedById) => {
      for (const r of refreshTokens.values()) {
        if (r.id === oldId) {
          r.revoked_at = new Date();
          r.replaced_by_id = replacedById;
          return;
        }
      }
    },
    hashToken,
    newRefreshToken,
  };
}

async function seedStudent(fixture, overrides = {}) {
  const passwordHash = await bcrypt.hash(overrides.password || 'Password123!', 4);
  return fixture.insertStudent({
    fullName: overrides.fullName || 'Test Student',
    email: overrides.email || `student-${crypto.randomUUID()}@example.com`,
    passwordHash,
    registrationNo: overrides.registrationNo || String(Math.floor(1000000000 + Math.random() * 8999999999)).slice(0, 10),
    department: overrides.department || 'CSE',
    session: overrides.session || '2023-24',
  });
}

async function seedTeacher(fixture, overrides = {}) {
  const passwordHash = await bcrypt.hash(overrides.password || 'Password123!', 4);
  return fixture.insertTeacher({
    fullName: overrides.fullName || 'Test Teacher',
    email: overrides.email || `teacher-${crypto.randomUUID()}@example.com`,
    passwordHash,
    teacherId: overrides.teacherId || `T-${crypto.randomUUID().slice(0, 6)}`,
    department: overrides.department || 'CSE',
    designation: overrides.designation || 'Lecturer',
  });
}

// =====================================================================
// Phase 6 fixtures: biometrics + attendance.
// =====================================================================
// Each fixture exposes Maps that mirror the DB tables the repos touch.
// Repo stubs read/write those Maps so service-layer tests are hermetic.

// ---- Biometrics repo stub (students device + face bindings) ----------
function makeBiometricsRepoStub() {
  const students = new Map(); // id -> student row

  return {
    students,
    findStudentById: async (studentId) => students.get(studentId) || null,
    findStudentByDeviceId: async (deviceId) => {
      for (const s of students.values()) {
        if (s.device_id === deviceId) return s;
      }
      return null;
    },
    bindFaceAndDevice: async ({ studentId, deviceId, ciphertext, iv, authTag }) => {
      const row = students.get(studentId);
      if (!row) return null;
      row.device_id = deviceId;
      row.is_device_locked = true;
      row.face_embedding_encrypted = ciphertext;
      row.face_embedding_iv = iv;
      row.face_embedding_auth_tag = authTag;
      row.face_enrolled_at = new Date();
      row.face_is_encrypted = true;
      row.updated_at = new Date();
      return {
        id: row.id,
        device_id: row.device_id,
        is_device_locked: row.is_device_locked,
        face_enrolled_at: row.face_enrolled_at,
        face_is_encrypted: row.face_is_encrypted,
      };
    },
  };
}

// Seed a student row directly into the biometrics students map.
// Returns the row so callers can grab id + manipulate columns.
function seedBiometricStudent(stub, overrides = {}) {
  const id = overrides.id || require('crypto').randomUUID();
  const row = {
    id,
    full_name: overrides.fullName || 'Test Student',
    email: overrides.email || `s-${id}@example.com`,
    registration_no: overrides.registrationNo || '20230001',
    department: overrides.department || 'CSE',
    session: overrides.session || '2023-24',
    device_id: overrides.deviceId || null,
    is_device_locked: !!overrides.isDeviceLocked,
    face_embedding_encrypted: overrides.faceEncrypted || null,
    face_embedding_iv: overrides.faceIv || null,
    face_embedding_auth_tag: overrides.faceAuthTag || null,
    face_enrolled_at: overrides.faceEnrolledAt || null,
    face_is_encrypted: !!overrides.faceIsEncrypted,
    is_active: overrides.isActive !== undefined ? !!overrides.isActive : true,
    token_version: 1,
  };
  stub.students.set(row.id, row);
  return row;
}

// ---- Attendance repo stub (sessions + records + audit) ----------------
function makeAttendanceRepoStub() {
  const sessions = new Map();  // id -> session row
  const records = new Map();   // key `${sessionId}:${studentId}` -> record
  const auditLogs = [];        // array of audit entries

  return {
    sessions,
    records,
    auditLogs,
    findSessionById: async (sessionId) => sessions.get(sessionId) || null,
    findStudentById: async (studentId) => {
      // cross-link: read from biometrics students map if available
      const biosStub = _biosStubRef.value;
      if (biosStub && biosStub.students.has(studentId)) {
        const s = biosStub.students.get(studentId);
        return {
          id: s.id,
          full_name: s.full_name,
          email: s.email,
          registration_no: s.registration_no,
          device_id: s.device_id,
          is_device_locked: s.is_device_locked,
          is_active: s.is_active,
          token_version: s.token_version,
        };
      }
      return null;
    },
    findExistingAttendance: async (sessionId, studentId) => {
      const r = records.get(`${sessionId}:${studentId}`);
      return r ? { id: r.id, marked_at: r.marked_at } : null;
    },
    insertAttendanceRecord: async ({
      sessionId, studentId, deviceId, similarity, isMockLocation,
    }) => {
      const id = require('crypto').randomUUID();
      const row = {
        id, session_id: sessionId, student_id: studentId,
        status: 'PRESENT', marked_at: new Date(),
        marked_device_id: deviceId,
        marked_face_similarity: similarity,
        marked_is_mock_location: !!isMockLocation,
      };
      records.set(`${sessionId}:${studentId}`, row);
      return {
        id: row.id,
        session_id: row.session_id,
        student_id: row.student_id,
        status: row.status,
        marked_at: row.marked_at,
      };
    },
    insertAuditLog: async (args) => {
      auditLogs.push({ ...args, id: auditLogs.length + 1, created_at: new Date() });
      return { rowCount: 1 };
    },
  };
}

// Hold a reference so attendanceRepoStub.findStudentById can read students
// seeded in the biometrics stub without a circular require dance.
const _biosStubRef = { value: null };

function seedSession(stub, overrides = {}) {
  const id = overrides.id || require('crypto').randomUUID();
  const inFuture = overrides.expiresAt || new Date(Date.now() + 10 * 60 * 1000);
  const row = {
    id,
    course_id: overrides.courseId || require('crypto').randomUUID(),
    title: overrides.title || 'Test Session',
    center_lat: overrides.centerLat || 24.9172,
    center_lng: overrides.centerLng || 91.8319,
    radius_meters: overrides.radiusMeters || 75,
    totp_secret: overrides.totpSecret || 'JBSWY3DPEHPK3PXP',
    expires_at: inFuture,
    is_active: overrides.isActive !== undefined ? !!overrides.isActive : true,
  };
  stub.sessions.set(row.id, row);
  return row;
}

function getStudent(fixture, id) {
  return fixture.students.get(id) || null;
}
function getSession(fixture, id) {
  return fixture.sessions.get(id) || null;
}
function getRecord(fixture, sessionId, studentId) {
  return fixture.records.get(`${sessionId}:${studentId}`) || null;
}

// Inject a stub into require.cache so services load it transparently.
// Path is resolved relative to backend/src/modules/<name>/<name>.repo.js
function injectRepoStub(moduleName, stub) {
  const path = require.resolve(
    `../../src/modules/${moduleName}/${moduleName}.repo.js`,
  );
  require.cache[path] = {
    id: path,
    filename: path,
    loaded: true,
    exports: stub,
  };
}

module.exports = {
  makeRepoFixture,
  hashToken,
  newRefreshToken,
  seedStudent,
  seedTeacher,
  // Phase 6
  makeBiometricsRepoStub,
  seedBiometricStudent,
  makeAttendanceRepoStub,
  seedSession,
  getStudent,
  getSession,
  getRecord,
  injectRepoStub,
  _setBiosRef: (v) => { _biosStubRef.value = v; },
};