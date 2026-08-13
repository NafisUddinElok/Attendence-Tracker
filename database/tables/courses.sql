-- Create Courses Table
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code VARCHAR(20) NOT NULL,            -- e.g. "IPE-301" or "CSE-101"
    title VARCHAR(150) NOT NULL,                  -- e.g. "Supply Chain Management"
    teacher_id UUID NOT NULL,                     -- Course creator
    department VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign Key Constraint
    CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
    
    -- Uniqueness constraint: Same teacher cannot have duplicate course codes
    CONSTRAINT unique_teacher_course_code UNIQUE (teacher_id, course_code)
);

CREATE INDEX IF NOT EXISTS idx_courses_teacher_id ON courses(teacher_id);