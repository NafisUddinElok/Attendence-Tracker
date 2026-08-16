// =====================================================================
// Biometrics service — face enrolment + verification.
// =====================================================================

const repo = require('./biometrics.repo');
const { encryptEmbedding, decryptEmbedding } = require('../../utils/faceCrypto');
const { calculateCosineSimilarity } = require('../../utils/securityUtils');
const env = require('../../config/env');
const { AppError } = require('../../errors/AppError');

const EMBED_DIM = env.FACE_EMBED_DIM;
const SIM_THRESHOLD = env.FACE_SIM_THRESHOLD;

/**
 * Validate a single embedding: must be a non-empty array of finite numbers
 * with the configured length.
 */
function assertValidEmbedding(emb) {
  if (!Array.isArray(emb) || emb.length === 0) {
    throw new AppError('INVALID_EMBEDDING', 'Embedding must be a non-empty array.', 400);
  }
  if (emb.length !== EMBED_DIM) {
    throw new AppError(
      'INVALID_EMBEDDING',
      `Embedding must be ${EMBED_DIM}-dimensional; got ${emb.length}.`,
      400,
      { expected: EMBED_DIM, received: emb.length },
    );
  }
  for (let i = 0; i < emb.length; i++) {
    if (!Number.isFinite(emb[i])) {
      throw new AppError('INVALID_EMBEDDING', `Non-finite value at index ${i}.`, 400);
    }
  }
}

/**
 * Average N embeddings into a single canonical vector, then re-normalise
 * to unit length. Pure JS, no external deps.
 *
 * @param {number[][]} embeddings  array of same-length vectors
 * @returns {number[]}            averaged + L2-normalised vector of length EMBED_DIM
 */
function averageEmbeddings(embeddings) {
  if (!Array.isArray(embeddings) || embeddings.length === 0) {
    throw new AppError('INVALID_EMBEDDING', 'At least one embedding is required.', 400);
  }
  const sum = new Array(EMBED_DIM).fill(0);
  for (const e of embeddings) {
    assertValidEmbedding(e);
    for (let i = 0; i < EMBED_DIM; i++) sum[i] += e[i];
  }
  const avg = sum.map((v) => v / embeddings.length);
  // L2-normalise so cosine similarity == dot product downstream.
  let norm = 0;
  for (let i = 0; i < EMBED_DIM; i++) norm += avg[i] * avg[i];
  norm = Math.sqrt(norm);
  if (norm === 0) {
    throw new AppError('INVALID_EMBEDDING', 'Average embedding has zero norm.', 400);
  }
  return avg.map((v) => v / norm);
}

/**
 * Compute a "weakness" score of an embedding set. Returns 0..1 indicating
 * how distinguishable the embeddings are from random noise. Low values
 * suggest the photo was too dark, too blurred, or not centred on a face.
 *
 * Currently: this is the magnitude of the variance across the N samples
 * after centring. If all samples are nearly identical (good lighting,
 * steady pose) the variance is tiny; if they diverge (bad capture) the
 * variance is large.
 *
 * Caller interprets: variance < TAU => WEAK_FACE.
 */
function varianceScore(embeddings) {
  const mean = new Array(EMBED_DIM).fill(0);
  for (const e of embeddings) {
    for (let i = 0; i < EMBED_DIM; i++) mean[i] += e[i] / embeddings.length;
  }
  let variance = 0;
  for (const e of embeddings) {
    for (let i = 0; i < EMBED_DIM; i++) {
      const d = e[i] - mean[i];
      variance += d * d;
    }
  }
  variance /= embeddings.length * EMBED_DIM;
  return variance;
}

/**
 * Enrol a student's face and bind their device.
 *
 * @param {object} input
 * @param {string} input.studentId
 * @param {string} input.deviceId
 * @param {number[][]} input.embeddings  at least one (multi-angle preferred)
 * @returns {Promise<{studentId: string, deviceId: string, faceEnrolledAt: Date}>}
 */
exports.enrollFace = async ({ studentId, deviceId, embeddings }) => {
  if (!studentId || !deviceId) {
    throw new AppError('VALIDATION_FAILED', 'studentId and deviceId are required.', 400);
  }
  if (!Array.isArray(embeddings) || embeddings.length === 0) {
    throw new AppError('VALIDATION_FAILED', 'embeddings[] is required.', 400);
  }

  // Reject if this device is already bound to another student.
  const owner = await repo.findStudentByDeviceId(deviceId);
  if (owner && owner.id !== studentId) {
    throw new AppError(
      'DEVICE_ALREADY_BOUND',
      'This device is already registered to another student.',
      409,
      { boundToStudentId: owner.id },
    );
  }

  // Reject if the student is already locked and trying to re-enrol.
  const me = await repo.findStudentById(studentId);
  if (!me) {
    throw new AppError('NOT_FOUND', 'Student not found.', 404);
  }
  if (me.is_device_locked && me.device_id !== deviceId) {
    throw new AppError(
      'DEVICE_LOCKED',
      'Account is locked to a different device. Admin reset required.',
      403,
    );
  }

  // Quality gate: reject if the captures look too jittered.
  const variance = varianceScore(embeddings);
  // Heuristic threshold: < 1e-4 means all samples are nearly identical.
  // Far below that means the input is degenerate (all zeros or constant).
  if (variance < 1e-7) {
    throw new AppError(
      'WEAK_FACE',
      'Face captures are too similar or degenerate. Re-capture with the guidance UI.',
      400,
      { variance },
    );
  }

  const canonical = averageEmbeddings(embeddings);
  const { ciphertext, iv, authTag } = encryptEmbedding(studentId, canonical);

  const row = await repo.bindFaceAndDevice({
    studentId, deviceId, ciphertext, iv, authTag,
  });
  if (!row) {
    throw new AppError('NOT_FOUND', 'Student not found.', 404);
  }

  return {
    studentId: row.id,
    deviceId: row.device_id,
    faceEnrolledAt: row.face_enrolled_at,
    varianceScore: variance,
  };
};

/**
 * Compare a candidate embedding against the stored canonical vector.
 * Returns the cosine similarity (0..1). Throws if the student has no
 * stored embedding (must enrol first).
 *
 * @param {string} studentId
 * @param {number[]} candidate
 * @returns {Promise<{similarity: number, threshold: number}>}
 */
exports.verifyFace = async (studentId, candidate) => {
  assertValidEmbedding(candidate);
  const row = await repo.findStudentById(studentId);
  if (!row) throw new AppError('NOT_FOUND', 'Student not found.', 404);
  if (!row.face_is_encrypted || !row.face_embedding_encrypted) {
    throw new AppError('FACE_NOT_ENROLLED', 'Face has not been enrolled for this student.', 400);
  }
  const stored = decryptEmbedding(
    studentId,
    row.face_embedding_encrypted,
    row.face_embedding_iv,
    row.face_embedding_auth_tag,
  );
  const similarity = calculateCosineSimilarity(stored, candidate);
  return { similarity, threshold: SIM_THRESHOLD, passed: similarity >= SIM_THRESHOLD };
};

module.exports = {
  enrollFace: exports.enrollFace,
  verifyFace: exports.verifyFace,
  // exposed for tests
  _averageEmbeddings: averageEmbeddings,
  _varianceScore: varianceScore,
  _assertValidEmbedding: assertValidEmbedding,
  EMBED_DIM,
  SIM_THRESHOLD,
};
