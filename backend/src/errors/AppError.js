/**
 * Domain error with HTTP + code semantics. Controllers/services throw this;
 * the error-handler middleware serializes it to the uniform JSON envelope.
 */
class AppError extends Error {
  /**
   * @param {string} code   Stable machine-readable code (e.g. EMAIL_TAKEN).
   * @param {string} message Human-readable message.
   * @param {number} status HTTP status code (defaults to 400).
   * @param {object} [details] Optional additional structured info.
   */
  constructor(code, message, status = 400, details = undefined) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

module.exports = { AppError };
