-- =====================================================================
-- Phase 6: One-Student, One-Device, One-Face
-- Add encrypted-face storage, bind columns, and audit columns.
-- Idempotent: every statement uses IF NOT EXISTS guards.
-- =====================================================================

-- 1. Encrypted face embedding for the stored canonical 128-D vector.
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS face_embedding_encrypted BYTEA,
    ADD COLUMN IF NOT EXISTS face_embedding_iv        BYTEA,
    ADD COLUMN IF NOT EXISTS face_embedding_auth_tag  BYTEA;

-- 2. Enrolment timestamp (also doubles as "face is bound" sentinel).
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS face_enrolled_at TIMESTAMPTZ;

-- 3. The old plaintext `face_embedding JSONB` column becomes redundant
--    once the encrypted columns are populated. We KEEP it during a 30-day
--    dual-write migration window and null it on every new enrol.
-- (no DROP here; left for later manual cleanup after migration sign-off)

-- 4. Indicate if encryption has been rolled out for a given student.
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS face_is_encrypted BOOLEAN NOT NULL DEFAULT FALSE;

-- 5. Forensic columns on attendance_records: keep what was used to mark.
ALTER TABLE attendance_records
    ADD COLUMN IF NOT EXISTS marked_device_id         VARCHAR(128),
    ADD COLUMN IF NOT EXISTS marked_face_similarity   REAL,
    ADD COLUMN IF NOT EXISTS marked_is_mock_location  BOOLEAN;

-- 6. Helpful index for "find the student whose device this is"
--    (already enforced unique by idx_students_device_id_unique from prior phase)
