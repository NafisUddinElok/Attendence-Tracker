/**
 * Wrap an async express handler so thrown errors are forwarded to the
 * error middleware (no manual try/catch in every controller).
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = { asyncHandler };
