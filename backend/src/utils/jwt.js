const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * Sign a short-lived JWT access token.
 * @param {string} sub  User id (UUID).
 * @param {string} role 'STUDENT' | 'TEACHER'
 * @param {number} ver  token_version (used for server-side invalidation).
 */
function signAccess(sub, role, ver = 1) {
  return jwt.sign(
    { sub, role, ver },
    env.JWT_ACCESS_SECRET,
    { expiresIn: env.JWT_ACCESS_TTL },
  );
}

/**
 * Verify and decode a JWT. Throws on invalid/expired token;
 * callers map the error to a 401 AppError.
 */
function verifyAccess(token) {
  return jwt.verify(token, env.JWT_ACCESS_SECRET);
}

module.exports = { signAccess, verifyAccess };
