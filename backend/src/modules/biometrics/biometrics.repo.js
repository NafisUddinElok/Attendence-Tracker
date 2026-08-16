// =====================================================================
// Biometrics repository — students device + face bindings.
// =====================================================================
// All access is parameterised; no string interpolation of user input.

const db = require('../../config/db');

/**
 * Find a student by id. Returns the full row including the encrypted
 * face columns and the device binding.
 */
exports.findStudentById = (studentId) =>
  db.query(
    `SELECT id, full_name, email, registration_no, department, session,
            device_id, is_device_locked,
            face_embedding_encrypted, face_embedding_iv, face_embedding_auth_tag,
            face_enrolled_at, face_is_encrypted, is_active, token_version
       FROM students
      WHERE id = $1
      LIMIT 1`,
    [studentId],
  ).then((r) => r.rows[0] || null);

/**
 * Look up a student by their bound device id. Used to enforce
 * one-student-one-device uniqueness at enrolment.
 */
exports.findStudentByDeviceId = (deviceId) =>
  db.query(
    `SELECT id, full_name, email, device_id, is_device_locked
       FROM students
      WHERE device_id = $1
      LIMIT 1`,
    [deviceId],
  ).then((r) => r.rows[0] || null);

/**
 * Persist a freshly computed canonical embedding and bind the device.
 * Stores the encrypted triplet (ciphertext, iv, authTag) plus mark
 * `is_device_locked = TRUE` and `face_enrolled_at = now()`.
 *
 * @param {object} args
 * @param {string} args.studentId
 * @param {string} args.deviceId
 * @param {Buffer} args.ciphertext
 * @param {Buffer} args.iv
 * @param {Buffer} args.authTag
 */
exports.bindFaceAndDevice = ({ studentId, deviceId, ciphertext, iv, authTag }) =>
  db.query(
    `UPDATE students
        SET device_id                = $2,
            is_device_locked         = TRUE,
            face_embedding_encrypted = $3,
            face_embedding_iv        = $4,
            face_embedding_auth_tag  = $5,
            face_enrolled_at         = now(),
            face_is_encrypted        = TRUE,
            updated_at               = now()
      WHERE id = $1
      RETURNING id, device_id, is_device_locked,
                face_enrolled_at, face_is_encrypted`,
    [studentId, deviceId, ciphertext, iv, authTag],
  ).then((r) => r.rows[0] || null);
