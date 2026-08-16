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

test('logout: revokes the active refresh token (silently)', async () => {
  await helpers.seedStudent(fixture, { email: 'bye@example.com', password: 'Password123!' });
  const login = await service.login({ email: 'bye@example.com', password: 'Password123!' }, {});

  await service.logout({ refreshToken: login.refreshToken });

  await assert.rejects(
    service.refresh({ refreshToken: login.refreshToken }),
    (e) => e instanceof AppError && e.code === 'REFRESH_REVOKED',
  );
});

test('logout: is idempotent for unknown tokens', async () => {
  await service.logout({ refreshToken: 'never-issued' }); // should not throw
});