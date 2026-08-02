// auth.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const db = require('./database/db');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('JWT_SECRET is not set. Add it to your .env file.');
}

function login(req, res) {
  const { studentCode, password } = req.body;

  if (typeof studentCode !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ success: false, message: 'studentCode and password are required.' });
  }

  const student = db.prepare('SELECT * FROM students WHERE student_code = ?').get(studentCode);

  // Same generic error whether the user doesn't exist or the password is wrong —
  // don't leak which one it was.
  if (!student || !bcrypt.compareSync(password, student.password_hash)) {
    return res.status(401).json({ success: false, message: 'Invalid credentials.' });
  }

  const token = jwt.sign(
    { studentId: student.id, studentCode: student.student_code },
    JWT_SECRET,
    { expiresIn: '8h' }
  );

  return res.json({ success: true, token });
}

// Middleware: verifies the JWT and attaches req.studentId.
// This is what makes studentId trustworthy server-side — it can no longer be
// spoofed by sending an arbitrary studentId in the request body.
function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.studentId = payload.studentId;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' });
  }
}

module.exports = { login, requireAuth };