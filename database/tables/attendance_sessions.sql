CREATE TABLE IF NOT EXISTS attendance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    course_id UUID NOT NULL,

    session_date DATE NOT NULL DEFAULT CURRENT_DATE,

    title VARCHAR(100) NOT NULL DEFAULT 'Regular Class',

    -- Geofence
    center_lat DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    center_lng DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    radius_meters INTEGER NOT NULL DEFAULT 50,

    -- Optional BLE verification
    ble_uuid VARCHAR(64),

    -- Session lifecycle
    expires_at TIMESTAMPTZ NOT NULL
        DEFAULT (CURRENT_TIMESTAMP + INTERVAL '15 minutes'),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_session_course
        FOREIGN KEY (course_id)
        REFERENCES courses(id)
        ON DELETE CASCADE,

    CONSTRAINT check_session_radius
        CHECK (radius_meters > 0 AND radius_meters <= 10000),

    CONSTRAINT check_session_latitude
        CHECK (center_lat BETWEEN -90 AND 90),

    CONSTRAINT check_session_longitude
        CHECK (center_lng BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS
    idx_sessions_course
ON attendance_sessions(course_id);

CREATE INDEX IF NOT EXISTS
    idx_sessions_active_course
ON attendance_sessions(course_id, is_active);

CREATE INDEX IF NOT EXISTS
    idx_sessions_expiry
ON attendance_sessions(expires_at);

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_one_active_session_per_course
ON attendance_sessions(course_id)
WHERE is_active = TRUE;