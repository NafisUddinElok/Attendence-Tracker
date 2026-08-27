-- =========================================================
-- ATTENDANCE SYSTEM - DATABASE SCHEMA (PostgreSQL)
-- =========================================================

CREATE TYPE user_role AS ENUM ('admin', 'teacher', 'student');
CREATE TYPE enrollment_status AS ENUM ('active', 'dropped');
CREATE TYPE session_status AS ENUM ('active', 'ended');
CREATE TYPE notification_status AS ENUM ('unread', 'read');
CREATE TYPE notification_type AS ENUM ('drop_course_enroll_request', 'general');

-- =========================================================
-- 1. USERS  (admin / teacher / student -- single table, role based)
-- =========================================================
CREATE TABLE users (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(150)  NOT NULL,
    email               VARCHAR(150)  UNIQUE NOT NULL,
    password            VARCHAR(255)  NOT NULL,          -- bcrypt hashed
    role                user_role     NOT NULL,
    registration_number VARCHAR(50)   UNIQUE,             -- only for students
    phone               VARCHAR(20),
    is_active           BOOLEAN       DEFAULT TRUE,
    created_at          TIMESTAMP     DEFAULT NOW(),
    updated_at          TIMESTAMP     DEFAULT NOW()
);

-- =========================================================
-- 2. COURSES
-- =========================================================
CREATE TABLE courses (
    id          SERIAL PRIMARY KEY,
    course_name VARCHAR(150) NOT NULL,
    course_code VARCHAR(30)  UNIQUE NOT NULL,
    teacher_id  INTEGER REFERENCES users(id) ON DELETE SET NULL,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);

-- =========================================================
-- 3. ENROLLMENTS (student <-> course mapping)
-- =========================================================
CREATE TABLE enrollments (
    id          SERIAL PRIMARY KEY,
    course_id   INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    student_id  INTEGER NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    status      enrollment_status DEFAULT 'active',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    dropped_at  TIMESTAMP,
    UNIQUE (course_id, student_id)
);

-- =========================================================
-- 4. SESSIONS (a single class instance opened by teacher)
-- =========================================================
CREATE TABLE sessions (
    id              SERIAL PRIMARY KEY,
    course_id       INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    teacher_id      INTEGER NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    session_date    DATE NOT NULL,
    start_time      TIMESTAMP NOT NULL DEFAULT NOW(),
    end_time        TIMESTAMP,
    latitude        DOUBLE PRECISION NOT NULL,   -- teacher's location when session started
    longitude       DOUBLE PRECISION NOT NULL,
    radius_meters   INTEGER NOT NULL DEFAULT 100, -- allowed range for students
    status          session_status DEFAULT 'active',
    csv_file_path   VARCHAR(255),                -- saved after session ends
    created_at      TIMESTAMP DEFAULT NOW()
);

-- =========================================================
-- 5. ATTENDANCE (per student, per session)
-- =========================================================
CREATE TABLE attendance (
    id               SERIAL PRIMARY KEY,
    session_id       INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    student_id       INTEGER NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    marked_at        TIMESTAMP DEFAULT NOW(),
    student_latitude  DOUBLE PRECISION NOT NULL,
    student_longitude DOUBLE PRECISION NOT NULL,
    distance_meters   DOUBLE PRECISION,          -- calculated distance from teacher location
    status            VARCHAR(20) DEFAULT 'present',
    UNIQUE (session_id, student_id)              -- ekbar e ekbar e attendance
);

-- =========================================================
-- 6. NOTIFICATIONS (admin panel e teacher's drop-course requests)
-- =========================================================
CREATE TABLE notifications (
    id           SERIAL PRIMARY KEY,
    type         notification_type DEFAULT 'general',
    sender_id    INTEGER REFERENCES users(id) ON DELETE SET NULL, -- teacher who requested
    receiver_id  INTEGER REFERENCES users(id) ON DELETE SET NULL, -- admin (or null = all admins)
    course_id    INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    student_registration_number VARCHAR(50),     -- registration no. teacher typed in manually
    message      TEXT,
    status       notification_status DEFAULT 'unread',
    created_at   TIMESTAMP DEFAULT NOW()
);

-- =========================================================
-- INDEXES (frequently queried columns)
-- =========================================================
CREATE INDEX idx_enrollments_course   ON enrollments(course_id);
CREATE INDEX idx_enrollments_student  ON enrollments(student_id);
CREATE INDEX idx_sessions_course      ON sessions(course_id);
CREATE INDEX idx_attendance_session   ON attendance(session_id);
CREATE INDEX idx_attendance_student   ON attendance(student_id);
CREATE INDEX idx_notifications_status ON notifications(status);
