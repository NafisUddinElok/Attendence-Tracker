-- Create Teachers Table
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    teacher_id VARCHAR(50) UNIQUE NOT NULL, -- e.g. EMP-101
    department VARCHAR(100),
    designation VARCHAR(100),             -- e.g. Assistant Professor, Lecturer
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookup during login
CREATE INDEX IF NOT EXISTS idx_teachers_email ON teachers(email);