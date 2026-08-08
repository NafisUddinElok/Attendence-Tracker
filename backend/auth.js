// auth.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const db = require('./database/db');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET is not set. Add it to your .env file.');
}

// --- Student registration ---------------------------------------------------
function register(req, res) {
  const { studentCode, name, password } = req.body;

  if (typeof studentCode !== 'string' || !studentCode.trim()) {
    return res.status(400).json({ success: false, message: 'studentCode is required.' });
  }
  if (typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ success: false, message: 'name is required.' });
  }
  if (typeof password !== 'string' || password.length < 6) {
    return res.status(400).json({ success: false, message: 'password must be at least 6 characters.' });
  }

  const existing = db.prepare('SELECT id FROM students WHERE student_code = ?').get(studentCode.trim());
  if (existing) {
    return res.status(409).json({ success: false, message: 'This student code is already registered.' });
  }

  const passwordHash = bcrypt.hashSync(password, 10);
  db.prepare('INSERT INTO students (student_code, name, password_hash) VALUES (?, ?, ?)')
    .run(studentCode.trim(), name.trim(), passwordHash);

  return res.json({ success: true, message: 'Registered successfully. You can now log in.' });
}

// --- Student login -----------------------------------------------------------
function login(req, res) {
  const { studentCode, password } = req.body;

  if (typeof studentCode !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ success: false, message: 'studentCode and password are required.' });
  }

  const student = db.prepare('SELECT * FROM students WHERE student_code = ?').get(studentCode);

  // Same generic error whether the user doesn't exist or the password is wrong.
  if (!student || !bcrypt.compareSync(password, student.password_hash)) {
    return res.status(401).json({ success: false, message: 'Invalid credentials.' });
  }

  const token = jwt.sign(
    { role: 'student', studentId: student.id, studentCode: student.student_code },
    JWT_SECRET,
    { expiresIn: '8h' }
  );

  return res.json({ success: true, token });
}

// Middleware: verifies the JWT and attaches req.studentId. Rejects teacher tokens.
function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    if (payload.role !== 'student') {
      return res.status(403).json({ success: false, message: 'A student account is required for this action.' });
    }
    req.studentId = payload.studentId;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' });
  }
}

// --- Teacher login -------------------------------------------------------------
function teacherLogin(req, res) {
  const { teacherCode, password } = req.body;

  if (typeof teacherCode !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ success: false, message: 'teacherCode and password are required.' });
  }

  const teacher = db.prepare('SELECT * FROM teachers WHERE teacher_code = ?').get(teacherCode);

  if (!teacher || !bcrypt.compareSync(password, teacher.password_hash)) {
    return res.status(401).json({ success: false, message: 'Invalid credentials.' });
  }

  const token = jwt.sign(
    { role: 'teacher', teacherId: teacher.id, teacherCode: teacher.teacher_code },
    JWT_SECRET,
    { expiresIn: '8h' }
  );

  return res.json({ success: true, token });
}

// Middleware: verifies the JWT and attaches req.teacherId. Rejects student tokens.
function requireTeacherAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    if (payload.role !== 'teacher') {
      return res.status(403).json({ success: false, message: 'A teacher account is required for this action.' });
    }
    req.teacherId = payload.teacherId;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' });
  }
}

module.exports = { register, login, requireAuth, teacherLogin, requireTeacherAuth };