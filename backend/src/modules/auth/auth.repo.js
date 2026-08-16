const db = require('../../config/db');
const crypto = require('crypto');

const STUDENT = 'students';
const TEACHER = 'teachers';

// NOTE: table names are constants from this source file, never user input;
// all values flow as parameterised query arguments.

exports.findStudentByEmail = (email) =>
  db.query(`SELECT * FROM ${STUDENT} WHERE email = $1 LIMIT 1`, [email]).then(r => r.rows[0] || null);

exports.findTeacherByEmail = (email) =>
  db.query(`SELECT * FROM ${TEACHER} WHERE email = $1 LIMIT 1`, [email]).then(r => r.rows[0] || null);

exports.findStudentByRegNo = (reg) =>
  db.query(`SELECT id FROM ${STUDENT} WHERE registration_no = $1 LIMIT 1`, [reg]).then(r => r.rows[0] || null);

exports.findTeacherByTeacherId = (tid) =>
  db.query(`SELECT id FROM ${TEACHER} WHERE teacher_id = $1 LIMIT 1`, [tid]).then(r => r.rows[0] || null);

exports.insertStudent = (s) =>
  db.query(
    `INSERT INTO ${STUDENT}
       (full_name, email, password_hash, registration_no, department, session)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, full_name, email, registration_no, department, session,
               is_active, token_version, created_at`,
    [s.fullName, s.email, s.passwordHash, s.registrationNo, s.department, s.session],
  ).then(r => r.rows[0]);

exports.insertTeacher = (s) =>
  db.query(
    `INSERT INTO ${TEACHER}
       (full_name, email, password_hash, teacher_id, department, designation)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, full_name, email, teacher_id, department, designation,
               is_active, token_version, created_at`,
    [s.fullName, s.email, s.passwordHash, s.teacherId, s.department, s.designation],
  ).then(r => r.rows[0]);

exports.updateLastLogin = (table, id) =>
  db.query(
    `UPDATE ${table} SET last_login_at = now(), updated_at = now() WHERE id = $1`,
    [id],
  );

exports.findById = (table, id) =>
  db.query(
    `SELECT id, full_name, email, is_active, token_version
       FROM ${table} WHERE id = $1 LIMIT 1`,
    [id],
  ).then(r => r.rows[0] || null);

// -------------------- Refresh tokens --------------------

exports.insertRefreshToken = (row) =>
  db.query(
    `INSERT INTO refresh_tokens
       (user_id, role, token_hash, expires_at, user_agent, ip)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, expires_at`,
    [row.userId, row.role, row.tokenHash, row.expiresAt, row.userAgent || null, row.ip || null],
  ).then(r => r.rows[0]);

exports.findActiveRefresh = (tokenHash) =>
  db.query(
    `SELECT id, user_id, role, parent_id, expires_at, revoked_at
       FROM refresh_tokens
      WHERE token_hash = $1
        AND revoked_at IS NULL
        AND expires_at > now()
      LIMIT 1`,
    [tokenHash],
  ).then(r => r.rows[0] || null);

exports.revokeRefresh = (id) =>
  db.query(
    `UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`,
    [id],
  );

exports.markReplaced = (oldId, replacedById) =>
  db.query(
    `UPDATE refresh_tokens SET revoked_at = now(), replaced_by_id = $2 WHERE id = $1`,
    [oldId, replacedById],
  );

// -------------------- helpers --------------------

exports.hashToken = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

exports.newRefreshToken = () =>
  crypto.randomBytes(32).toString('hex');
