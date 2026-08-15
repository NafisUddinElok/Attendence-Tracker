-- ============================================================
-- Phase A - Attendance Security Migration
-- Migration: 001_phase_a_security.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0. Required extension
-- ------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ------------------------------------------------------------
-- 1. STUDENT SECURITY FIELDS
-- ------------------------------------------------------------

ALTER TABLE students
    ADD COLUMN IF NOT EXISTS device_id VARCHAR(128),
    ADD COLUMN IF NOT EXISTS face_embedding JSONB,
    ADD COLUMN IF NOT EXISTS is_device_locked BOOLEAN NOT NULL DEFAULT FALSE;


-- ------------------------------------------------------------
-- 2. ATTENDANCE SESSION SECURITY FIELDS
-- ------------------------------------------------------------

ALTER TABLE attendance_sessions
    ADD COLUMN IF NOT EXISTS center_lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS center_lng DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS radius_meters INTEGER,
    ADD COLUMN IF NOT EXISTS totp_secret VARCHAR(64),
    ADD COLUMN IF NOT EXISTS ble_uuid VARCHAR(64),
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN;


-- ------------------------------------------------------------
-- 3. BACKFILL EXISTING SESSION DATA
-- ------------------------------------------------------------

UPDATE attendance_sessions
SET
    center_lat = COALESCE(center_lat, 0.0),
    center_lng = COALESCE(center_lng, 0.0),
    radius_meters = COALESCE(radius_meters, 50),
    totp_secret = COALESCE(
        totp_secret,
        encode(gen_random_bytes(20), 'hex')
    ),
    expires_at = COALESCE(
        expires_at,
        created_at + INTERVAL '15 minutes'
    ),
    is_active = COALESCE(is_active, TRUE);


-- ------------------------------------------------------------
-- 4. MAKE SESSION SECURITY FIELDS REQUIRED
-- ------------------------------------------------------------

ALTER TABLE attendance_sessions
    ALTER COLUMN center_lat SET NOT NULL,
    ALTER COLUMN center_lng SET NOT NULL,
    ALTER COLUMN radius_meters SET NOT NULL,
    ALTER COLUMN totp_secret SET NOT NULL,
    ALTER COLUMN expires_at SET NOT NULL,
    ALTER COLUMN is_active SET NOT NULL;


-- ------------------------------------------------------------
-- 5. DEFAULT VALUES FOR FUTURE ROWS
-- ------------------------------------------------------------

ALTER TABLE attendance_sessions
    ALTER COLUMN center_lat SET DEFAULT 0.0,
    ALTER COLUMN center_lng SET DEFAULT 0.0,
    ALTER COLUMN radius_meters SET DEFAULT 50,
    ALTER COLUMN totp_secret SET DEFAULT encode(gen_random_bytes(20), 'hex'),
    ALTER COLUMN expires_at SET DEFAULT (CURRENT_TIMESTAMP + INTERVAL '15 minutes'),
    ALTER COLUMN is_active SET DEFAULT TRUE;


-- ------------------------------------------------------------
-- 6. VALIDATION CONSTRAINTS
-- ------------------------------------------------------------

ALTER TABLE attendance_sessions
    DROP CONSTRAINT IF EXISTS check_session_radius;

ALTER TABLE attendance_sessions
    ADD CONSTRAINT check_session_radius
    CHECK (radius_meters > 0 AND radius_meters <= 10000);


ALTER TABLE attendance_sessions
    DROP CONSTRAINT IF EXISTS check_session_latitude;

ALTER TABLE attendance_sessions
    ADD CONSTRAINT check_session_latitude
    CHECK (center_lat BETWEEN -90 AND 90);


ALTER TABLE attendance_sessions
    DROP CONSTRAINT IF EXISTS check_session_longitude;

ALTER TABLE attendance_sessions
    ADD CONSTRAINT check_session_longitude
    CHECK (center_lng BETWEEN -180 AND 180);


-- ------------------------------------------------------------
-- 7. DEVICE UNIQUENESS
-- ------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_students_device_id_unique
ON students(device_id)
WHERE device_id IS NOT NULL;


-- ------------------------------------------------------------
-- 8. SESSION LOOKUP INDEXES
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS
    idx_attendance_sessions_active_course
ON attendance_sessions(course_id, is_active);

CREATE INDEX IF NOT EXISTS
    idx_attendance_sessions_expiry
ON attendance_sessions(expires_at);


-- ------------------------------------------------------------
-- 9. ONLY ONE ACTIVE SESSION PER COURSE
-- ------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_one_active_session_per_course
ON attendance_sessions(course_id)
WHERE is_active = TRUE;


-- ------------------------------------------------------------
-- 10. ATTENDANCE RECORD LOOKUP
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS
    idx_attendance_records_student
ON attendance_records(student_id);

CREATE INDEX IF NOT EXISTS
    idx_attendance_records_session_student
ON attendance_records(session_id, student_id);


-- ------------------------------------------------------------
-- 11. AUDIT LOG INDEXES
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS
    idx_audit_created_at
ON attendance_audit_logs(created_at);

CREATE INDEX IF NOT EXISTS
    idx_audit_status
ON attendance_audit_logs(status);


COMMIT;