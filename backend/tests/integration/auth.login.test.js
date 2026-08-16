const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const path = require('node:path');

// Install a stub repo into module cache BEFORE loading service.
const helpers = require('./_helpers');
const fixture = helpers.makeRepoFixture();

const repoStub = { ...fixture };
const repoPath = path.resolve(__dirname, '../../src/modules/auth/auth.repo.js');
require.cache[repoPath] = {
  id: repoPath,
  filename: repoPath,
  loaded: true,
  exports: repoStub,
};

const service = require('../../src/modules/auth/auth.service');
const { AppError } = require('../../src/errors/AppError');

test('login: happy path returns access + refresh and a public student', async () => {
  const seeded = await helpers.seedStudent(fixture, { email: 'alice@example.com', password: 'Password123!' });
  const out = await service.login({ email: 'alice@example.com', password: 'Password123!' }, {});
  assert.equal(out.user.email, 'alice@example.com');
  assert.equal(out.user.role, 'STUDENT');
  assert.equal(out.user.id, seeded.id);
  assert.ok(out.accessToken.length > 10);
  assert.ok(out.refreshToken.length === 64);
});

test('login: rejects wrong password with AUTH_INVALID_CREDENTIALS', async () => {
  await helpers.seedStudent(fixture, { email: 'bob@example.com', password: 'Password123!' });
  await assert.rejects(
    service.login({ email: 'bob@example.com', password: 'WRONG' }, {}),
    (e) => e instanceof AppError && e.code === 'AUTH_INVALID_CREDENTIALS',
  );
});

test('login: rejects unknown email with AUTH_INVALID_CREDENTIALS', async () => {
  await assert.rejects(
    service.login({ email: 'nobody@example.com', password: 'Password123!' }, {}),
    (e) => e instanceof AppError && e.code === 'AUTH_INVALID_CREDENTIALS',
  );
});

test('login: works for teachers too (role discovered server-side)', async () => {
  const seeded = await helpers.seedTeacher(fixture, { email: 'prof@example.com', password: 'Password123!' });
  const out = await service.login({ email: 'prof@example.com', password: 'Password123!' }, {});
  assert.equal(out.user.role, 'TEACHER');
  assert.equal(out.user.id, seeded.id);
});