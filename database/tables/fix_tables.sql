-- 1. Ensure students table has new columns
ALTER TABLE students 
ADD COLUMN IF NOT EXISTS device_id VARCHAR(128) UNIQUE,
ADD COLUMN IF NOT EXISTS face_embedding JSONB,
ADD COLUMN IF NOT EXISTS is_device_locked BOOLEAN DEFAULT FALSE;

-- 2. Ensure attendance_sessions table has all security columns
ALTER TABLE attendance_sessions 
ADD COLUMN IF NOT EXISTS center_lat DOUBLE PRECISION NOT NULL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS center_lng DOUBLE PRECISION NOT NULL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS radius_meters INT NOT NULL DEFAULT 50,
ADD COLUMN IF NOT EXISTS ble_uuid VARCHAR(64),
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT (CURRENT_TIMESTAMP + INTERVAL '15 minutes'),
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 3. Create ENUM Type for Attendance Status safely
DO $$ BEGIN
    CREATE TYPE attendance_status AS ENUM ('PRESENT', 'ABSENT', 'LATE');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 4. Create attendance_records table
CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    student_id UUID NOT NULL,
    status attendance_status NOT NULL DEFAULT 'PRESENT',
    marked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_record_session FOREIGN KEY (session_id) REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    CONSTRAINT fk_record_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT unique_session_student UNIQUE (session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_records_session ON attendance_records(session_id);

-- 5. Create attendance_audit_logs table
CREATE TABLE IF NOT EXISTS attendance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES attendance_sessions(id) ON DELETE SET NULL,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL,
    device_id VARCHAR(128),
    attempted_lat DOUBLE PRECISION,
    attempted_lng DOUBLE PRECISION,
    is_mock_location BOOLEAN DEFAULT FALSE,
    similarity_score DOUBLE PRECISION,
    status VARCHAR(30) NOT NULL,
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_session ON attendance_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_student ON attendance_audit_logs(student_id);