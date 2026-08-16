-- database/init.sql
\echo 'Creating Teachers Table...'
\i tables/teachers.sql

\echo 'Creating Students Table...'
\i tables/students.sql

\echo 'Creating Courses Table...'
\i tables/courses.sql

\echo 'Creating Enrollments Table...'
\i tables/enrollments.sql

\echo 'Creating Attendance Sessions Table...'
\i tables/attendance_sessions.sql

\echo 'Creating Attendance Records Table...'
\i tables/attendance_records.sql

\echo 'Creating Attendance Audit Logs Table...'
\i tables/attendance_audit_logs.sql

\echo 'Applying Phase E auth migration...'
\i migrations/002_phase_e_auth.sql

\echo '✅ All Database tables created successfully!'