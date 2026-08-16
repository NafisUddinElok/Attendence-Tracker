const bcrypt = require('bcryptjs');
const repo = require('./auth.repo');
const { signAccess } = require('../../utils/jwt');
const env = require('../../config/env');
const { AppError } = require('../../errors/AppError');

const BCRYPT_COST = env.BCRYPT_COST;

function publicStudent(row) {
  return {
    id: row.id,
    role: 'STUDENT',
    fullName: row.full_name,
    email: row.email,
    registrationNo: row.registration_no,
    department: row.department || null,
    session: row.session || null,
  };
}

function publicTeacher(row) {
  return {
    id: row.id,
    role: 'TEACHER',
    fullName: row.full_name,
    email: row.email,
    teacherId: row.teacher_id,
    department: row.department || null,
    designation: row.designation || null,
  };
}

async function hashPassword(plain) {
  return bcrypt.hash(plain, BCRYPT_COST);
}

async function verifyPassword(plain, hash) {
  if (!hash) return false;
  return bcrypt.compare(plain, hash);
}

async function issueNewTokens({ userId, role, tokenVersion, meta }) {
  const refreshToken = repo.newRefreshToken();
  const tokenHash = repo.hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + env.REFRESH_TTL_DAYS * 24 * 3600 * 1000);

  await repo.insertRefreshToken({
    userId,
    role,
    tokenHash,
    expiresAt,
    userAgent: meta?.ua,
    ip: meta?.ip,
  });

  const accessToken = signAccess(userId, role, tokenVersion || 1);
  return { accessToken, refreshToken };
}

// ===========================================================
// REGISTER
// ===========================================================

exports.registerStudent = async (input, meta) => {
  if (await repo.findStudentByEmail(input.email)) {
    throw new AppError('EMAIL_TAKEN', 'Email already registered.', 409, { field: 'email' });
  }
  if (await repo.findStudentByRegNo(input.registrationNo)) {
    throw new AppError('REG_NO_TAKEN', 'Registration number already registered.', 409, { field: 'registrationNo' });
  }

  const passwordHash = await hashPassword(input.password);
  const row = await repo.insertStudent({
    fullName: input.fullName,
    email: input.email,
    passwordHash,
    registrationNo: input.registrationNo,
    department: input.department || null,
    session: input.session || null,
  });

  const tokens = await issueNewTokens({
    userId: row.id, role: 'STUDENT', tokenVersion: row.token_version, meta,
  });

  return { user: publicStudent(row), ...tokens };
};

exports.registerTeacher = async (input, meta) => {
  if (await repo.findTeacherByEmail(input.email)) {
    throw new AppError('EMAIL_TAKEN', 'Email already registered.', 409, { field: 'email' });
  }
  if (await repo.findTeacherByTeacherId(input.teacherId)) {
    throw new AppError('TEACHER_ID_TAKEN', 'Teacher ID already registered.', 409, { field: 'teacherId' });
  }

  const passwordHash = await hashPassword(input.password);
  const row = await repo.insertTeacher({
    fullName: input.fullName,
    email: input.email,
    passwordHash,
    teacherId: input.teacherId,
    department: input.department || null,
    designation: input.designation || null,
  });

  const tokens = await issueNewTokens({
    userId: row.id, role: 'TEACHER', tokenVersion: row.token_version, meta,
  });

  return { user: publicTeacher(row), ...tokens };
};

// ===========================================================
// LOGIN
// ===========================================================

exports.login = async ({ email, password }, meta) => {
  // Server discovers role by matching the email against both tables.
  // We never trust a client-supplied `role` field.
  const [student, teacher] = await Promise.all([
    repo.findStudentByEmail(email),
    repo.findTeacherByEmail(email),
  ]);

  const candidates = [];
  if (student) candidates.push({ row: student, role: 'STUDENT', table: 'students' });
  if (teacher) candidates.push({ row: teacher, role: 'TEACHER', table: 'teachers' });

  if (candidates.length === 0) {
    throw new AppError('AUTH_INVALID_CREDENTIALS', 'Email or password is incorrect.', 400);
  }

  let match = null;
  for (const c of candidates) {
    if (!c.row.is_active) continue;
    // eslint-disable-next-line no-await-in-loop
    if (await verifyPassword(password, c.row.password_hash)) {
      match = c;
      break;
    }
  }

  if (!match) {
    throw new AppError('AUTH_INVALID_CREDENTIALS', 'Email or password is incorrect.', 400);
  }

  await repo.updateLastLogin(match.table, match.row.id);

  const tokens = await issueNewTokens({
    userId: match.row.id,
    role: match.role,
    tokenVersion: match.row.token_version,
    meta,
  });

  const user = match.role === 'STUDENT' ? publicStudent(match.row) : publicTeacher(match.row);
  return { user, ...tokens };
};

// ===========================================================
// REFRESH — single-use rotation
// ===========================================================

exports.refresh = async ({ refreshToken }) => {
  const tokenHash = repo.hashToken(refreshToken);
  const row = await repo.findActiveRefresh(tokenHash);
  if (!row) {
    throw new AppError('REFRESH_REVOKED', 'Refresh token is invalid or revoked.', 401);
  }

  // Look up the user to get the current token_version.
  const table = row.role === 'STUDENT' ? 'students' : 'teachers';
  const user = await repo.findById(table, row.user_id);
  if (!user || !user.is_active) {
    throw new AppError('REFRESH_REVOKED', 'Account is inactive.', 401);
  }

  const newRefresh = repo.newRefreshToken();
  const newHash = repo.hashToken(newRefresh);
  const expiresAt = new Date(Date.now() + env.REFRESH_TTL_DAYS * 24 * 3600 * 1000);

  const inserted = await repo.insertRefreshToken({
    userId: row.user_id,
    role: row.role,
    tokenHash: newHash,
    expiresAt,
  });

  await repo.markReplaced(row.id, inserted.id);

  const accessToken = signAccess(row.user_id, row.role, user.token_version);
  return { accessToken, refreshToken: newRefresh };
};

// ===========================================================
// LOGOUT — revoke the supplied refresh token
// ===========================================================

exports.logout = async ({ refreshToken }) => {
  const tokenHash = repo.hashToken(refreshToken);
  const row = await repo.findActiveRefresh(tokenHash);
  if (row) await repo.revokeRefresh(row.id);
};

// ===========================================================
// ME
// ===========================================================

exports.me = async ({ id, role }) => {
  const table = role === 'STUDENT' ? 'students' : 'teachers';
  // fetch via email-less lookup using the same find helper
  const row = await dbQueryFindById(table, id);
  if (!row) throw new AppError('NOT_FOUND', 'User not found.', 404);
  return role === 'STUDENT' ? publicStudent(row) : publicTeacher(row);
};

// small local helper to avoid an extra import noise in module.exports
async function dbQueryFindById(table, id) {
  const db = require('../../config/db');
  const r = await db.query(
    `SELECT id, full_name, email, registration_no, department, session,
            teacher_id, designation, is_active, token_version
       FROM ${table} WHERE id = $1 LIMIT 1`,
    [id],
  );
  return r.rows[0] || null;
}
