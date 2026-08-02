// backend/server.js
// Main entry point. Mounts each attendance-method feature as its own router,
// matching the backend/facialdetection, backend/geofencing, backend/qr layout.

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const { login } = require('./auth');
const geofencingRoutes = require('./geofencing/geo');

// If/when facialdetection and qr get their own route modules, mount them
// the same way, e.g.:
// const facialDetectionRoutes = require('./facialdetection/routes');
// const qrRoutes = require('./qr/routes');

const app = express();
app.use(express.json());

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
app.use(cors({ origin: ALLOWED_ORIGINS.length ? ALLOWED_ORIGINS : false }));

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many login attempts. Try again later.' },
});

app.post('/login', loginLimiter, login);

app.use('/geofencing', geofencingRoutes);
// app.use('/facialdetection', facialDetectionRoutes);
// app.use('/qr', qrRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Attendance server running on port ${PORT}`));