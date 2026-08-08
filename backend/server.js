// backend/server.js
// Main entry point. Mounts each feature as its own router.

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const { register, login, teacherRegister, teacherLogin } = require('./auth');
const geofencingRoutes = require('./geofencing/geo');
const coursesRoutes = require('./courses/courses');
const sessionsRoutes = require('./sessions/sessions');

const app = express();
app.use(express.json());

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
app.use(cors({ origin: ALLOWED_ORIGINS.length ? ALLOWED_ORIGINS : false }));

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many attempts. Try again later.' },
});

app.post('/register', authLimiter, register);
app.post('/login', authLimiter, login);
app.post('/teacher-register', authLimiter, teacherRegister);
app.post('/teacher-login', authLimiter, teacherLogin);

app.use('/geofencing', geofencingRoutes);
app.use('/courses', coursesRoutes);
app.use('/sessions', sessionsRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Attendance server running on port ${PORT}`));