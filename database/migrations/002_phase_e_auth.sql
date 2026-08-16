-- ============================================================
-- Phase E - Auth Hardening Migration
-- Migration: 002_phase_e_auth.sql
-- ============================================================
-- Adds:
--   1) terms                       (academic semester)
--   2) refresh_tokens              (hashed, rotating)
--   3) students.is_active, token_version, last_login_at, updated_at
--   4) teachers.is_active, token_version, last_login_at, updated_at
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. STUDENT AUTH HARDENING
-- ------------------------------------------------------------

ALTER TABLE students
    ADD COLUMN IF NOT EXISTS is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS token_version  INTEGER     NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS last_login_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- ------------------------------------------------------------
-- 2. TEACHER AUTH HARDENING
-- ------------------------------------------------------------

ALTER TABLE teachers
    ADD COLUMN IF NOT EXISTS is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS token_version  INTEGER     NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS last_login_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- ------------------------------------------------------------
-- 3. ACADEMIC TERMS
-- ============================================================
CREATE TABLE IF NOT EXISTS terms (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(40)  NOT NULL UNIQUE,                       -- 'SPRING-2026'
    label       VARCHAR(100) NOT NULL,                              -- 'Spring 2026'
    starts_on   DATE         NOT NULL,
    ends_on     DATE         NOT NULL,
    is_current  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_term_window CHECK (ends_on >= starts_on)
);

-- Only one current term at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_terms_one_current
    ON terms ((TRUE)) WHERE is_current;

-- ------------------------------------------------------------
-- 4. REFRESH TOKENS (server-authoritative, hashed)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL,
    role            VARCHAR(16)  NOT NULL CHECK (role IN ('STUDENT','TEACHER')),
    token_hash      CHAR(64)     NOT NULL UNIQUE,
    parent_id       UUID         REFERENCES refresh_tokens(id) ON DELETE SET NULL,
    issued_at       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMPTZ  NOT NULL,
    revoked_at      TIMESTAMPTZ,
    replaced_by_id  UUID         REFERENCES refresh_tokens(id) ON DELETE SET NULL,
    user_agent      VARCHAR(255),
    ip              INET,
    CONSTRAINT fk_refresh_teacher
        FOREIGN KEY (user_id) REFERENCES teachers(id) ON DELETE CASCADE,
    CONSTRAINT fk_refresh_student
        FOREIGN KEY (user_id) REFERENCES students(id)  ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_refresh_user_active
    ON refresh_tokens(user_id) WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_expires
    ON refresh_tokens(expires_at);

COMMIT;