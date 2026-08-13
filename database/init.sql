-- database/init.sql
\echo 'Creating Teachers Table...'
\i tables/teachers.sql

\echo 'Creating Students Table...'
\i tables/students.sql

\echo 'Creating Courses Table...'
\i tables/courses.sql

\echo 'Creating Enrollments Table...'
\i tables/enrollments.sql

\echo 'Database initialization complete!'