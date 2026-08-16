// =====================================================================
// Face Embedding Crypto — AES-256-GCM with per-student HKDF-derived key.
// =====================================================================
//
// Storage strategy:
//   * Stored vector -> encrypted at rest with AES-256-GCM.
//   * Key derivation: HKDF-SHA256(secret = JWT_ACCESS_SECRET,
//                                salt  = KDF_PEPPER,
//                                info  = studentId)
//   * This means a DB leak alone is insufficient - the attacker also
//     needs the JWT secret + KDF pepper to recover a usable vector.
//   * Vector is encoded as 4-byte little-endian float32 per dimension
//     (128 floats => 512 bytes plaintext) before encryption.
// =====================================================================

const crypto = require('crypto');
const env = require('../config/env');

const ALGO = 'aes-256-gcm';
const KEY_LEN = 32; // 256 bits
const IV_LEN = 12;  // 96 bits (GCM standard)
const TAG_LEN = 16; // 128 bits

/**
 * Derive a per-student 256-bit AES key from the JWT secret and pepper.
 * @param {string} studentId
 * @returns {Buffer}
 */
function deriveKey(studentId) {
  if (!studentId) throw new Error('deriveKey requires studentId');
  const ikm = Buffer.from(String(env.JWT_ACCESS_SECRET), 'utf8');
  const salt = Buffer.from(String(env.KDF_PEPPER), 'utf8');
  const info = Buffer.from(`face-emb:${studentId}`, 'utf8');
  return crypto.hkdfSync('sha256', ikm, salt, info, KEY_LEN);
}

/**
 * Encode a numeric array (e.g. 128-D face embedding) as a Buffer of
 * little-endian float32 values. Throws on non-finite values.
 * @param {number[]} vec
 * @returns {Buffer}
 */
function encodeVector(vec) {
  if (!Array.isArray(vec) || vec.length === 0) {
    throw new Error('encodeVector: input must be a non-empty array');
  }
  const buf = Buffer.alloc(vec.length * 4);
  for (let i = 0; i < vec.length; i++) {
    const v = Number(vec[i]);
    if (!Number.isFinite(v)) {
      throw new Error(`encodeVector: non-finite value at index ${i}`);
    }
    buf.writeFloatLE(v, i * 4);
  }
  return buf;
}

/**
 * Decode a Buffer of little-endian float32 values back to a number array.
 * @param {Buffer} buf
 * @returns {number[]}
 */
function decodeVector(buf) {
  if (!Buffer.isBuffer(buf) || buf.length === 0 || buf.length % 4 !== 0) {
    throw new Error('decodeVector: invalid buffer');
  }
  const out = new Array(buf.length / 4);
  for (let i = 0; i < out.length; i++) {
    out[i] = buf.readFloatLE(i * 4);
  }
  return out;
}

/**
 * Encrypt a face embedding for a given student.
 * @param {string} studentId
 * @param {number[]} embedding
 * @returns {{ciphertext: Buffer, iv: Buffer, authTag: Buffer}}
 */
function encryptEmbedding(studentId, embedding) {
  const key = deriveKey(studentId);
  const iv = crypto.randomBytes(IV_LEN);
  const cipher = crypto.createCipheriv(ALGO, key, iv, { authTagLength: TAG_LEN });
  const plaintext = encodeVector(embedding);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return { ciphertext, iv, authTag };
}

/**
 * Decrypt a stored face embedding back to its numeric vector.
 * Throws if the auth tag does not verify (tampered ciphertext).
 * @param {string} studentId
 * @param {Buffer} ciphertext
 * @param {Buffer} iv
 * @param {Buffer} authTag
 * @returns {number[]}
 */
function decryptEmbedding(studentId, ciphertext, iv, authTag) {
  if (!Buffer.isBuffer(ciphertext) || !Buffer.isBuffer(iv) || !Buffer.isBuffer(authTag)) {
    throw new Error('decryptEmbedding: ciphertext/iv/authTag must be Buffers');
  }
  const key = deriveKey(studentId);
  const decipher = crypto.createDecipheriv(ALGO, key, iv, { authTagLength: TAG_LEN });
  decipher.setAuthTag(authTag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return decodeVector(plaintext);
}

module.exports = {
  encryptEmbedding,
  decryptEmbedding,
  encodeVector,
  decodeVector,
  // exposed for tests
  _deriveKey: deriveKey,
};
