-- Sample Teachers
INSERT INTO teachers (full_name, email, password_hash, teacher_id, department, designation)
VALUES 
('Dr. Ahmed Khan', 'ahmed@teacher.edu', '$2b$10$SampleHashedPassword1', 'EMP-101', 'CSE', 'Associate Professor')
ON CONFLICT (email) DO NOTHING;

-- Sample Students
INSERT INTO students (full_name, email, password_hash, registration_no, department, session)
VALUES 
('Rahim Uddin', 'rahim@student.edu', '$2b$10$SampleHashedPassword2', '2020331001', 'CSE', '2020-21')
ON CONFLICT (email) DO NOTHING;