const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const helpers = require('./_helpers');
const fixture = helpers.makeRepoFixture();
const repoPath = path.resolve(__dirname, '../../src/modules/auth/auth.repo.js');
require.cache[repoPath] = {
  id: repoPath, filename: repoPath, loaded: true, exports: fixture,
};

const service = require('../../src/modules/auth/auth.service');
const { AppError } = require('../../src/errors/AppError');

test('registerStudent: happy path', async () => {
  const out = await service.registerStudent({
    fullName: 'Alice Wonderland',
    email: 'alice@example.com',
    password: 'Password123!',
    registrationNo: '2023101001',
    department: 'CSE',
    session: '2023-24',
  }, {});
  assert.equal(out.user.role, 'STUDENT');
  assert.equal(out.user.email, 'alice@example.com');
  assert.ok(out.accessToken.length > 10);
  assert.equal(out.refreshToken.length, 64);
});

test('registerStudent: rejects duplicate email', async () => {
  await service.registerStudent({
    fullName: 'Dup User',
    email: 'dup@example.com',
    password: 'Password123!',
    registrationNo: '2023101002',
  }, {});
  await assert.rejects(
    service.registerStudent({
      fullName: 'Dup User 2',
      email: 'dup@example.com',
      password: 'Password123!',
      registrationNo: '2023101003',
    }, {}),
    (e) => e instanceof AppError && e.code === 'EMAIL_TAKEN',
  );
});

test('registerTeacher: happy path', async () => {
  const out = await service.registerTeacher({
    fullName: 'Prof. Plum',
    email: 'plum@example.com',
    password: 'Password123!',
    teacherId: 'T-001',
    department: 'EEE',
    designation: 'Associate Professor',
  }, {});
  assert.equal(out.user.role, 'TEACHER');
  assert.equal(out.user.email, 'plum@example.com');
  assert.ok(out.accessToken.length > 10);
});

test('registerTeacher: rejects duplicate teacherId', async () => {
  await service.registerTeacher({
    fullName: 'Prof. A',
    email: 'a@example.com',
    password: 'Password123!',
    teacherId: 'T-002',
  }, {});
  await assert.rejects(
    service.registerTeacher({
      fullName: 'Prof. B',
      email: 'b@example.com',
      password: 'Password123!',
      teacherId: 'T-002',
    }, {}),
    (e) => e instanceof AppError && e.code === 'TEACHER_ID_TAKEN',
  );
});