const db = require('../config/db');
const { isValidUUID } = require('../utils/securityUtils');


// -------------------------------------------------------------
// TEACHER: Create a New Course
// -------------------------------------------------------------
exports.createCourse = async (req, res) => {
  const { courseCode, title, department } = req.body;
  const teacherId = req.user.id;

  if (!courseCode || !title) {
    return res.status(400).json({ message: 'Course code and title are required.' });
  }

  try {
    // Check if teacher already has this course code
    const existing = await db.query(
      'SELECT id FROM courses WHERE teacher_id = $1 AND course_code = $2',
      [teacherId, courseCode.toUpperCase().trim()]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ message: 'You already created a course with this code.' });
    }

    const result = await db.query(
      `INSERT INTO courses (course_code, title, teacher_id, department)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [courseCode.toUpperCase().trim(), title.trim(), teacherId, department || null]
    );

    res.status(201).json({
      message: 'Course created successfully',
      course: result.rows[0],
    });
  } catch (error) {
    console.error('Create Course Error:', error);
    res.status(500).json({ message: 'Server error while creating course.' });
  }
};

// -------------------------------------------------------------
// TEACHER: Delete Course
// -------------------------------------------------------------
exports.deleteCourse = async (req, res) => {
  const { id } = req.params;
  const teacherId = req.user.id;

  try {
    const result = await db.query(
      'DELETE FROM courses WHERE id = $1 AND teacher_id = $2 RETURNING id, course_code',
      [id, teacherId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Course not found or unauthorized to delete.' });
    }

    res.status(200).json({
      message: `Course ${result.rows[0].course_code} deleted successfully.`,
    });
  } catch (error) {
    console.error('Delete Course Error:', error);
    res.status(500).json({ message: 'Server error while deleting course.' });
  }
};

// -------------------------------------------------------------
// TEACHER: Get All Created Courses with Enrolled Student Count
// -------------------------------------------------------------
exports.getTeacherCourses = async (req, res) => {
  const teacherId = req.user.id;

  try {
    const query = `
      SELECT 
        c.id,
        c.course_code,
        c.title,
        c.department,
        c.created_at,
        COUNT(e.id)::int AS enrolled_students_count
      FROM courses c
      LEFT JOIN enrollments e ON c.id = e.course_id
      WHERE c.teacher_id = $1
      GROUP BY c.id
      ORDER BY c.created_at DESC;
    `;

    const result = await db.query(query, [teacherId]);
    res.status(200).json({ courses: result.rows });
  } catch (error) {
    console.error('Get Teacher Courses Error:', error);
    res.status(500).json({ message: 'Server error fetching teacher courses.' });
  }
};

// -------------------------------------------------------------
// STUDENT: Get All Courses with `is_enrolled` status
// -------------------------------------------------------------
exports.getStudentCourses = async (req, res) => {
  const studentId = req.user.id;

  try {
    const query = `
      SELECT 
        c.id,
        c.course_code,
        c.title,
        c.department,
        t.full_name AS teacher_name,
        t.email AS teacher_email,
        CASE 
          WHEN e.student_id IS NOT NULL THEN TRUE 
          ELSE FALSE 
        END AS is_enrolled
      FROM courses c
      JOIN teachers t ON c.teacher_id = t.id
      LEFT JOIN enrollments e 
        ON c.id = e.course_id 
       AND e.student_id = $1
      ORDER BY c.course_code ASC;
    `;

    const result = await db.query(query, [studentId]);
    res.status(200).json({ courses: result.rows });
  } catch (error) {
    console.error('Get Student Courses Error:', error);
    res.status(500).json({ message: 'Server error fetching courses for student.' });
  }
};

// -------------------------------------------------------------
// STUDENT: Enroll in a Course
// -------------------------------------------------------------
exports.enrollCourse = async (req, res) => {
  const { courseId } = req.body;
  const studentId = req.user.id;

  // UUID Format Guard
  if (!isValidUUID(courseId)) {
    return res.status(400).json({ message: 'Invalid Course ID format. Please provide a valid UUID.' });
  }

  try {
    // Check if course exists
    const courseCheck = await db.query('SELECT id FROM courses WHERE id = $1', [courseId]);
    if (courseCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Course not found.' });
    }

    // Insert into enrollments
    await db.query(
      'INSERT INTO enrollments (student_id, course_id) VALUES ($1, $2)',
      [studentId, courseId]
    );

    res.status(201).json({ message: 'Enrolled in course successfully.' });
  } catch (error) {
    if (error.code === '23505') { // Unique constraint violation (already enrolled)
      return res.status(400).json({ message: 'You are already enrolled in this course.' });
    }
    console.error('Enroll Course Error:', error);
    res.status(500).json({ message: 'Server error during enrollment.' });
  }
};

// -------------------------------------------------------------
// STUDENT: Unenroll / Drop a Course
// -------------------------------------------------------------
exports.unenrollCourse = async (req, res) => {
  const { courseId } = req.params;
  const studentId = req.user.id;

  try {
    const result = await db.query(
      'DELETE FROM enrollments WHERE student_id = $1 AND course_id = $2 RETURNING id',
      [studentId, courseId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Enrollment record not found.' });
    }

    res.status(200).json({ message: 'Unenrolled from course successfully.' });
  } catch (error) {
    console.error('Unenroll Error:', error);
    res.status(500).json({ message: 'Server error during unenrollment.' });
  }
};

// -------------------------------------------------------------
// TEACHER: View & Search Enrolled Students for a specific Course
// -------------------------------------------------------------
exports.getEnrolledStudents = async (req, res) => {
  const { id: courseId } = req.params;
  const teacherId = req.user.id;
  const search = req.query.search || ''; // Query param: ?search=2023831005 or ?search=Nafis

  try {
    // 1. Verify course belongs to this teacher
    const courseCheck = await db.query(
      'SELECT id, course_code, title FROM courses WHERE id = $1 AND teacher_id = $2',
      [courseId, teacherId]
    );

    if (courseCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Course not found or unauthorized.' });
    }

    // 2. Fetch enrolled students with optional search
    const query = `
      SELECT 
        s.id,
        s.full_name,
        s.email,
        s.registration_no,
        s.department,
        s.session,
        e.enrolled_at
      FROM enrollments e
      JOIN students s ON e.student_id = s.id
      WHERE e.course_id = $1
        AND (
          s.full_name ILIKE $2 OR 
          s.registration_no ILIKE $2
        )
      ORDER BY s.registration_no ASC;
    `;

    const result = await db.query(query, [courseId, `%${search}%`]);

    res.status(200).json({
      course: courseCheck.rows[0],
      totalEnrolled: result.rows.length,
      students: result.rows,
    });
  } catch (error) {
    console.error('Get Enrolled Students Error:', error);
    res.status(500).json({ message: 'Server error fetching enrolled students.' });
  }
};