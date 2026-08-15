DO $$
BEGIN
    CREATE TYPE attendance_status
    AS ENUM ('PRESENT', 'ABSENT', 'LATE');
EXCEPTION
    WHEN duplicate_object THEN
        NULL;
END $$;



CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    session_id UUID NOT NULL,

    student_id UUID NOT NULL,

    status attendance_status NOT NULL DEFAULT 'PRESENT',

    marked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_record_session
        FOREIGN KEY (session_id)
        REFERENCES attendance_sessions(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_record_student
        FOREIGN KEY (student_id)
        REFERENCES students(id)
        ON DELETE CASCADE,

    CONSTRAINT unique_session_student
        UNIQUE (session_id, student_id)
);

CREATE INDEX IF NOT EXISTS
    idx_records_session
ON attendance_records(session_id);

CREATE INDEX IF NOT EXISTS
    idx_records_student
ON attendance_records(student_id);

CREATE INDEX IF NOT EXISTS
    idx_records_session_student
ON attendance_records(session_id, student_id);