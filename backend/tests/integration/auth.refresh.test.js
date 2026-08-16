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

test('refresh: rotates tokens and revokes the old refresh token', async () => {
  await helpers.seedStudent(fixture, { email: 'rot@example.com', password: 'Password123!' });
  const login = await service.login({ email: 'rot@example.com', password: 'Password123!' }, {});
  const r1 = login.refreshToken;

  const next = await service.refresh({ refreshToken: r1 });
  assert.notEqual(next.refreshToken, r1);

  // Old token is now revoked — reusing it must throw.
  await assert.rejects(
    service.refresh({ refreshToken: r1 }),
    (e) => e instanceof AppError && e.code === 'REFRESH_REVOKED',
  );
});

test('refresh: rejects garbage tokens', async () => {
  await assert.rejects(
    service.refresh({ refreshToken: 'not-a-real-token' }),
    (e) => e instanceof AppError && e.code === 'REFRESH_REVOKED',
  );
});