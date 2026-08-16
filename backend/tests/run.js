// Cross-platform test runner used by `npm test`.
process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test-access-secret';

const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const dir = path.resolve(__dirname, 'integration');
const files = fs.readdirSync(dir).filter((f) => f.endsWith('.test.js'))
  .map((f) => path.join(dir, f));

if (files.length === 0) {
  console.error('No test files found in', dir);
  process.exit(1);
}

const r = spawnSync(
  process.execPath,
  ['--test', ...files],
  { stdio: 'inherit', env: process.env },
);
process.exit(r.status ?? 1);
