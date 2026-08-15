const express = require('express');
const router = express.Router();
const courseController = require('../controllers/courseController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

// Unified & Role-protected Course Routes
router.post('/', protect, authorizeRoles('TEACHER'), courseController.createCourse);
router.get('/', protect, courseController.getCourses);
router.delete('/:id', protect, authorizeRoles('TEACHER'), courseController.deleteCourse);
router.get('/:id/students', protect, authorizeRoles('TEACHER'), courseController.getEnrolledStudents);

// Student Specific Routes
router.post('/enroll', protect, authorizeRoles('STUDENT'), courseController.enrollCourse);
router.delete('/unenroll/:courseId', protect, authorizeRoles('STUDENT'), courseController.unenrollCourse);

module.exports = router;