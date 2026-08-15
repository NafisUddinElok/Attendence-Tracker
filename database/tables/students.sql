CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    full_name VARCHAR(100) NOT NULL,

    email VARCHAR(255) UNIQUE NOT NULL,

    password_hash VARCHAR(255) NOT NULL,

    registration_no VARCHAR(10) UNIQUE NOT NULL,

    department VARCHAR(100),

    session VARCHAR(20),

    -- Phase B preparation
    device_id VARCHAR(128),

    face_embedding JSONB,

    is_device_locked BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT check_sust_reg_no
        CHECK (registration_no ~ '^[0-9]{10}$')
);

CREATE INDEX IF NOT EXISTS
    idx_students_reg_no
ON students(registration_no);

CREATE INDEX IF NOT EXISTS
    idx_students_email
ON students(email);

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_students_device_id_unique
ON students(device_id)
WHERE device_id IS NOT NULL;