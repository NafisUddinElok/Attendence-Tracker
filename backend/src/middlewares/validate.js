const { AppError } = require('../errors/AppError');

/**
 * Tiny request validator so we don't need `zod` for the auth slice.
 * A schema is `{ body?: (obj)=>{ok:true,value}|{ok:false,errors:FieldError[]} }`.
 *
 * FieldError: { field: string, message: string }.
 */
function validate(schemas) {
  return (req, res, next) => {
    const issues = [];
    for (const part of ['body', 'params', 'query']) {
      const validator = schemas && schemas[part];
      if (!validator) continue;
      const input = req[part] || {};
      const result = safeRun(validator, input);
      if (!result.ok) {
        for (const e of result.errors) issues.push({ in: part, field: e.field, message: e.message });
      } else {
        req[part] = result.value;
      }
    }
    if (issues.length) {
      return next(new AppError('VALIDATION_FAILED', 'Request validation failed.', 400, { issues }));
    }
    next();
  };
}

function safeRun(validator, input) {
  try {
    return validator(input);
  } catch (e) {
    return { ok: false, errors: [{ field: '_', message: e.message || 'invalid' }] };
  }
}

module.exports = { validate };
