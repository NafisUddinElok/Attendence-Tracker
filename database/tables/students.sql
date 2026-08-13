-- Create Students Table with SUST Reg No Validation
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    registration_no VARCHAR(10) UNIQUE NOT NULL, -- SUST Reg No (e.g. 2023831005)
    department VARCHAR(100),
    session VARCHAR(20),                         -- e.g. 2023-24
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint: Registration number must be exactly 10 numeric digits
    CONSTRAINT check_sust_reg_no CHECK (registration_no ~ '^[0-9]{10}$')
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_students_reg_no ON students(registration_no);
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);