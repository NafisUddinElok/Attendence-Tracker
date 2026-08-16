const { AppError } = require('../errors/AppError');
const env = require('../config/env');

/**
 * Single global error serializer. Mounted last in app.js.
 *  - AppError → straight mapping using its code/status/message/details.
 *  - pg unique violation 23505 → 409 UNIQUE_VIOLATION.
 *  - JWT errors → 401 AUTH_BAD_TOKEN.
 *  - everything else → 500 INTERNAL (full error only in development).
 */
function errorHandler(err, req, res, _next) {
  if (err instanceof AppError) {
    return res.status(err.status).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
    });
  }

  if (err && err.code === '23505') {
    return res.status(409).json({
      error: {
        code: 'UNIQUE_VIOLATION',
        message: 'Resource already exists.',
        details: { constraint: err.constraint },
      },
    });
  }

  if (err && (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError')) {
    return res.status(401).json({
      error: { code: 'AUTH_BAD_TOKEN', message: 'Invalid or expired token.' },
    });
  }

  // eslint-disable-next-line no-console
  console.error('[unhandled]', err);
  return res.status(500).json({
    error: {
      code: 'INTERNAL',
      message: 'Internal server error.',
      details: env.NODE_ENV === 'development' ? { message: err.message, stack: err.stack } : undefined,
    },
  });
}

module.exports = { errorHandler };
