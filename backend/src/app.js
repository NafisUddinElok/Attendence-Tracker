const express = require('express');
const cors = require('cors');
const env = require('./config/env');
const authRoutes = require('./modules/auth/auth.routes');
const biometricsRoutes = require('./modules/biometrics/biometrics.routes');
const errorHandler = require('./middlewares/errorHandler');

// legacy route modules (kept until cutover to /api/v1/*)
const courseRoutes = require('./routes/courseRoutes');
const sessionRoutes = require('./routes/sessionRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const reportRoutes = require('./routes/reportRoutes');

function buildApp() {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);

  app.use(express.json({ limit: '1mb' }));

  const origins = env.CORS_ORIGINS;
  app.use(cors({
    origin: origins === '*' || !origins
      ? true
      : origins.split(',').map(s => s.trim()).filter(Boolean),
    credentials: true,
  }));

  app.get('/health', (_req, res) => res.json({ ok: true }));

  // New canonical API
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/biometrics', biometricsRoutes);

  // Transitional mounts for backward compatibility
  app.use('/api/auth', authRoutes);

  // Legacy domain routes (unchanged for now)
  app.use('/api/courses', courseRoutes);
  app.use('/api/sessions', sessionRoutes);
  app.use('/api/attendance', attendanceRoutes);
  app.use('/api/reports', reportRoutes);

  app.use((req, res, next) => {
    res.status(404).json({ error: { code: 'NOT_FOUND', message: `No route ${req.method} ${req.path}` } });
  });

  app.use(errorHandler);

  return app;
}

module.exports = { buildApp };