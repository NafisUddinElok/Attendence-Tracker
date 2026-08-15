const db = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Generate JWT Token
const generateToken = (id, role) => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
};

// -------------------------------------------------------------
// REGISTER USER (Student / Teacher)
// -------------------------------------------------------------
exports.register = async (req, res) => {
  const { role, fullName, email, password, code, department, session, designation } = req.body;

  if (!role || !fullName || !email || !password || !code) {
    return res.status(400).json({ message: 'Please provide all required fields' });
  }

  try {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    if (role.toUpperCase() === 'STUDENT') {
      // Check 10-digit SUST Reg No
      if (!/^\d{10}$/.test(code)) {
        return res.status(400).json({ message: 'SUST Registration number must be 10 digits' });
      }

      // Check if student exists
      const existing = await db.query(
        'SELECT id FROM students WHERE email = $1 OR registration_no = $2',
        [email, code]
      );
      if (existing.rows.length > 0) {
        return res.status(400).json({ message: 'Student with this email or reg no already exists' });
      }

      // Insert Student
      const newStudent = await db.query(
        `INSERT INTO students (full_name, email, password_hash, registration_no, department, session)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, full_name, email, registration_no, department, session`,
        [fullName, email, passwordHash, code, department || null, session || null]
      );

      const user = newStudent.rows[0];
      const token = generateToken(user.id, 'STUDENT');

      return res.status(201).json({
        message: 'Student registered successfully',
        token,
        user: { ...user, role: 'STUDENT' },
      });

    } else if (role.toUpperCase() === 'TEACHER') {
      // Check if teacher exists
      const existing = await db.query(
        'SELECT id FROM teachers WHERE email = $1 OR teacher_id = $2',
        [email, code]
      );
      if (existing.rows.length > 0) {
        return res.status(400).json({ message: 'Teacher with this email or teacher ID already exists' });
      }

      // Insert Teacher
      const newTeacher = await db.query(
        `INSERT INTO teachers (full_name, email, password_hash, teacher_id, department, designation)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, full_name, email, teacher_id, department, designation`,
        [fullName, email, passwordHash, code, department || null, designation || null]
      );

      const user = newTeacher.rows[0];
      const token = generateToken(user.id, 'TEACHER');

      return res.status(201).json({
        message: 'Teacher registered successfully',
        token,
        user: { ...user, role: 'TEACHER' },
      });

    } else {
      return res.status(400).json({ message: 'Invalid role specified' });
    }
  } catch (error) {
    console.error('Registration Error:', error);
    res.status(500).json({ message: 'Server error during registration' });
  }
};

// -------------------------------------------------------------
// LOGIN USER (Student / Teacher)
// -------------------------------------------------------------
exports.login = async (req, res) => {
  const { role, email, password } = req.body;

  if (!role || !email || !password) {
    return res.status(400).json({ message: 'Please provide role, email, and password' });
  }

  try {
    const table = role.toUpperCase() === 'TEACHER' ? 'teachers' : 'students';
    
    // Find user by email
    const result = await db.query(`SELECT * FROM ${table} WHERE email = $1`, [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Verify Password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Remove password hash from response
    delete user.password_hash;

    const token = generateToken(user.id, role.toUpperCase());

    res.status(200).json({
      message: 'Login successful',
      token,
      user: { ...user, role: role.toUpperCase() },
    });
  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
};


// -------------------------------------------------------------
// STUDENT: Register Device ID & Face Embedding Vector
// -------------------------------------------------------------
exports.registerBiometrics = async (req, res) => {
  const { deviceId, faceEmbedding } = req.body;
  const studentId = req.user.id;

  if (!deviceId || typeof deviceId !== 'string' || deviceId.trim() === '') {
    return res.status(400).json({ message: 'A valid deviceId is required.' });
  }

  if (!Array.isArray(faceEmbedding) || faceEmbedding.length === 0) {
    return res.status(400).json({ message: 'A valid faceEmbedding float array is required.' });
  }

  try {
    // Check if student's device is already locked to another phone
    const existing = await db.query(
      'SELECT device_id, is_device_locked FROM students WHERE id = $1',
      [studentId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ message: 'Student record not found.' });
    }

    if (existing.rows[0].is_device_locked && existing.rows[0].device_id !== deviceId) {
      return res.status(403).json({
        message: 'Device is already locked. Contact department admin to reset your registered device.',
      });
    }

    // Save Face Embedding (as JSONB) and Device ID
    await db.query(
      `UPDATE students 
       SET device_id = $1, 
           face_embedding = $2, 
           is_device_locked = TRUE 
       WHERE id = $3`,
      [deviceId.trim(), JSON.stringify(faceEmbedding), studentId]
    );

    res.status(200).json({
      message: 'Face biometrics and primary device registered successfully!',
      isDeviceLocked: true,
    });
  } catch (error) {
    console.error('Register Biometrics Error:', error);
    res.status(500).json({ message: 'Server error while saving biometrics.' });
  }
};