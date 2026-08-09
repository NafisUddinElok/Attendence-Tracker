// database/updateSessionLocation.js
//
// Usage:
//   node database/updateSessionLocation.js <sessionId> <latitude> <longitude> [radiusMeters]
//
// Example:
//   node database/updateSessionLocation.js 1 23.8104 90.4126 50

const db = require('./db');

const [, , sessionId, lat, lng, radius] = process.argv;

if (!sessionId || !lat || !lng) {
  console.error('Usage: node database/updateSessionLocation.js <sessionId> <latitude> <longitude> [radiusMeters]');
  process.exit(1);
}

const result = db.prepare(`
  UPDATE class_sessions
  SET latitude = ?, longitude = ?, radius_meters = ?
  WHERE id = ?
`).run(parseFloat(lat), parseFloat(lng), radius ? parseInt(radius, 10) : 50, parseInt(sessionId, 10));

if (result.changes === 0) {
  console.error(`No session found with id ${sessionId}`);
  process.exit(1);
}

console.log(`Session ${sessionId} location updated to (${lat}, ${lng}), radius ${radius || 50}m`);