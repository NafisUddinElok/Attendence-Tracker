CREATE TABLE IF NOT EXISTS attendance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES attendance_sessions(id) ON DELETE SET NULL,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL,
    device_id VARCHAR(128),
    attempted_lat DOUBLE PRECISION,
    attempted_lng DOUBLE PRECISION,
    is_mock_location BOOLEAN DEFAULT FALSE,
    similarity_score DOUBLE PRECISION,
    status VARCHAR(30) NOT NULL, -- 'SUCCESS', 'FAILED_GEOFENCE', 'FAILED_FACE', 'FAILED_DEVICE', 'FAILED_TOKEN'
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_session ON attendance_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_student ON attendance_audit_logs(student_id);