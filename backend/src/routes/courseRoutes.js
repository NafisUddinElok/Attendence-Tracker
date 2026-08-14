const express = require('express');
const router = express.Router();
const courseController = require('../controllers/courseController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

// All course routes require login
router.use(protect);

// ---------------- TEACHER ROUTES ----------------
router.post(
  '/',
  authorizeRoles('TEACHER'),
  courseController.createCourse
);

router.get(
  '/teacher',
  authorizeRoles('TEACHER'),
  courseController.getTeacherCourses
);

router.delete(
  '/:id',
  authorizeRoles('TEACHER'),
  courseController.deleteCourse
);

// ---------------- STUDENT ROUTES ----------------
router.get(
  '/student',
  authorizeRoles('STUDENT'),
  courseController.getStudentCourses
);

router.post(
  '/enroll',
  authorizeRoles('STUDENT'),
  courseController.enrollCourse
);

router.delete(
  '/enroll/:courseId',
  authorizeRoles('STUDENT'),
  courseController.unenrollCourse
);

// Teacher route to view/search enrolled students inside a course
router.get(
  '/:id/students',
  authorizeRoles('TEACHER'),
  courseController.getEnrolledStudents
);

module.exports = router;