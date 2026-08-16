const { verifyAccess } = require('../utils/jwt');
const { AppError } = require('../errors/AppError');

/**
 * Verify the JWT access token and populate `req.user = { id, role, ver }`.
 * 401 with a structured AppError on failure.
 */
exports.protect = (req, _res, next) => {
  const header = req.headers.authorization || '';
  let token = null;
  if (header.startsWith('Bearer ')) token = header.slice('Bearer '.length).trim();
  if (!token) {
    return next(new AppError('AUTH_NO_TOKEN', 'Access denied. No token provided.', 401));
  }
  try {
    const decoded = verifyAccess(token);
    req.user = { id: decoded.sub, role: decoded.role, ver: decoded.ver };
    next();
  } catch (_err) {
    next(new AppError('AUTH_BAD_TOKEN', 'Invalid or expired token.', 401));
  }
};

/**
 * Authorize one of the given roles. Use after `protect`.
 */
exports.requireRole = (...roles) => (req, _res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return next(new AppError(
      'FORBIDDEN_ROLE',
      `Role '${req.user && req.user.role}' is not authorized for this route.`,
      403,
    ));
  }
  next();
};

// Backwards-compatible alias for existing routes that use `authorizeRoles`.
exports.authorizeRoles = exports.requireRole;