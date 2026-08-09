// database/extendSession.js
//
// Refreshes an existing session's active time window without touching its
// location — useful while testing, since the app's sessionId is hardcoded
// and re-running seed.js would create a brand new session with a new id.
//
// Usage:
//   node database/extendSession.js <sessionId> [durationMinutes]
//
// Example (extend session 1 to be active for another 60 minutes, starting now):
//   node database/extendSession.js 1 60

const db = require('./db');

const [, , sessionId, durationMinutes] = process.argv;

if (!sessionId) {
  console.error('Usage: node database/extendSession.js <sessionId> [durationMinutes]');
  process.exit(1);
}

const duration = durationMinutes ? parseInt(durationMinutes, 10) : 60;
const now = new Date();
const startsAt = new Date(now.getTime() - 2 * 60 * 1000).toISOString(); // started 2 min ago, avoids clock-skew edge cases
const endsAt = new Date(now.getTime() + duration * 60 * 1000).toISOString();

const result = db.prepare(`
  UPDATE class_sessions
  SET starts_at = ?, ends_at = ?
  WHERE id = ?
`).run(startsAt, endsAt, parseInt(sessionId, 10));

if (result.changes === 0) {
  console.error(`No session found with id ${sessionId}`);
  process.exit(1);
}

console.log(`Session ${sessionId} is now active until ${endsAt}`);