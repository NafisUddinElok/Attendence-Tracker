const http = require('http');
const { Server } = require('socket.io');
const env = require('./config/env');
const { buildApp } = require('./app');

const app = buildApp();
const server = http.createServer(app);

// Optional first-boot migration. Render Postgres comes empty; setting
// DB_BOOTSTRAP=1 in the service env runs init.sql + migrations/*.sql once
// at startup. Every statement uses IF NOT EXISTS guards so this is safe
// on every redeploy (no-op after the first run).
if (String(process.env.DB_BOOTSTRAP || env.DB_BOOTSTRAP || '0') === '1') {
  // Lazy import so the dependency is only paid when bootstrap is requested.
  // eslint-disable-next-line global-require
  const { migrate } = require('./db/migrate');
  // eslint-disable-next-line no-console
  console.log('[bootstrap] DB_BOOTSTRAP=1 — running migrations…');
  migrate()
    // eslint-disable-next-line no-console
    .then(() => console.log('[bootstrap] migrations complete'))
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[bootstrap] migration failed:', err.message);
      // Fail fast so Render marks the deploy as crashed and we notice.
      process.exit(1);
    });
}

const io = new Server(server, {
  cors: {
    origin: env.CORS_ORIGINS === '*' || !env.CORS_ORIGINS
      ? true
      : env.CORS_ORIGINS.split(',').map(s => s.trim()).filter(Boolean),
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

// Socket.io connection logic for Live Teacher Screen
io.on('connection', (socket) => {
  // Join a room for a specific attendance session
  socket.on('join_session', (sessionId) => {
    socket.join(`session_${sessionId}`);
  });
});

// Expose `io` to route handlers
app.use((req, _res, next) => {
  req.io = io;
  next();
});

const PORT = Number(process.env.PORT || env.PORT || 3000);
server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(
    `[server] listening on :${PORT} (${env.NODE_ENV})` +
      (process.env.RENDER_EXTERNAL_URL
        ? ` | public: ${process.env.RENDER_EXTERNAL_URL}`
        : '')
  );
});

module.exports = { app, server, io };