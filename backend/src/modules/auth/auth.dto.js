/**
 * Minimal, dependency-free validators for the auth slice.
 * Each schema is `{ body?, params?, query? }` mapping to a function
 * `(input) => { ok: true, value } | { ok: false, errors: [{field,message}] }`.
 */

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function ok(value) { return { ok: true, value }; }
function err(errors) { return { ok: false, errors }; }

function str(issues, acc, key, val, opts) {
  if (typeof val !== 'string' || val.trim() === '') {
    issues.push({ field: key, message: `${opts.label || key} is required.` });
    acc[key] = '';
    return;
  }
  const trimmed = val.trim();
  if (opts.min != null && trimmed.length < opts.min) {
    issues.push({ field: key, message: `${opts.label || key} must be at least ${opts.min} characters.` });
  }
  if (opts.max != null && trimmed.length > opts.max) {
    issues.push({ field: key, message: `${opts.label || key} must be at most ${opts.max} characters.` });
  }
  if (opts.regex && !opts.regex.test(trimmed)) {
    issues.push({ field: key, message: opts.regexMsg || `${opts.label || key} format is invalid.` });
  }
  acc[key] = opts.upper ? trimmed.toUpperCase() : trimmed;
}

function pass(issues, acc, key, val, opts) {
  if (typeof val !== 'string' || val === '') {
    issues.push({ field: key, message: 'Password is required.' });
    acc[key] = '';
    return;
  }
  if (val.length < (opts.min || 8)) {
    issues.push({ field: key, message: `Password must be at least ${opts.min || 8} characters.` });
  }
  if (val.length > (opts.max || 72)) {
    issues.push({ field: key, message: `Password must be at most ${opts.max || 72} characters.` });
  }
  acc[key] = val;
}

function optStr(issues, acc, key, val, opts) {
  if (val === undefined || val === null || val === '') { acc[key] = null; return; }
  if (typeof val !== 'string') {
    issues.push({ field: key, message: `${opts.label || key} must be a string.` });
    acc[key] = null;
    return;
  }
  const trimmed = val.trim();
  if (opts.max != null && trimmed.length > opts.max) {
    issues.push({ field: key, message: `${opts.label || key} must be at most ${opts.max} characters.` });
  }
  acc[key] = trimmed.length ? trimmed : null;
}

// ===========================================================
// studentRegister: { fullName, email, password, registrationNo, department?, session? }
// ===========================================================
const studentRegister = {
  body(input) {
    const issues = [];
    const acc = {};
    str(issues, acc, 'fullName', input.fullName, { min: 2, max: 100, label: 'Full name' });
    str(issues, acc, 'email',    input.email,    { max: 255, regex: EMAIL_RE, regexMsg: 'Enter a valid email address.', label: 'Email' });
    pass(issues, acc, 'password', input.password, { min: 8, max: 72 });
    str(issues, acc, 'registrationNo', input.registrationNo,
        { regex: /^\d{10}$/, regexMsg: 'Registration number must be exactly 10 digits.', label: 'Registration number' });
    optStr(issues, acc, 'department', input.department, { max: 100, label: 'Department' });
    optStr(issues, acc, 'session',    input.session,    { max: 20, label: 'Session' });
    return issues.length ? err(issues) : ok(acc);
  },
};

// ===========================================================
// teacherRegister: { fullName, email, password, teacherId, department?, designation? }
// ===========================================================
const teacherRegister = {
  body(input) {
    const issues = [];
    const acc = {};
    str(issues, acc, 'fullName', input.fullName, { min: 2, max: 100, label: 'Full name' });
    str(issues, acc, 'email',    input.email,    { max: 255, regex: EMAIL_RE, regexMsg: 'Enter a valid email address.', label: 'Email' });
    pass(issues, acc, 'password', input.password, { min: 8, max: 72 });
    str(issues, acc, 'teacherId', input.teacherId,
        { min: 1, max: 50, regex: /^[A-Za-z0-9\-_.]+$/,
          regexMsg: 'Teacher ID may only contain letters, digits, dash, underscore, dot.', label: 'Teacher ID' });
    optStr(issues, acc, 'department',  input.department,  { max: 100, label: 'Department' });
    optStr(issues, acc, 'designation', input.designation, { max: 100, label: 'Designation' });
    return issues.length ? err(issues) : ok(acc);
  },
};

// ===========================================================
// login: { email, password }
// ===========================================================
const login = {
  body(input) {
    const issues = [];
    const acc = {};
    str(issues, acc, 'email',    input.email,    { max: 255, regex: EMAIL_RE, regexMsg: 'Enter a valid email address.', label: 'Email' });
    pass(issues, acc, 'password', input.password, { min: 1 });
    return issues.length ? err(issues) : ok(acc);
  },
};

// ===========================================================
// refresh: { refreshToken }
// ===========================================================
const refresh = {
  body(input) {
    const issues = [];
    const acc = {};
    str(issues, acc, 'refreshToken', input.refreshToken, { min: 20, max: 256, label: 'Refresh token' });
    return issues.length ? err(issues) : ok(acc);
  },
};

// ===========================================================
// logout: { refreshToken } (access token via Authorization header)
// ===========================================================
const logout = {
  body(input) {
    const issues = [];
    const acc = {};
    str(issues, acc, 'refreshToken', input.refreshToken, { min: 20, max: 256, label: 'Refresh token' });
    return issues.length ? err(issues) : ok(acc);
  },
};

module.exports = { studentRegister, teacherRegister, login, refresh, logout };
