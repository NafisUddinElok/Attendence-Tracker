const router = require('express').Router();
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const adminController = require('../controllers/adminController');

// All admin routes require: logged in + role === admin
router.use(auth, roleCheck('admin'));

// Teachers
router.post('/teachers', adminController.createTeacher);
router.get('/teachers', adminController.getAllTeachers);

// Students
router.post('/students', adminController.createStudent);
router.get('/students', adminController.getAllStudents);

// Courses
router.post('/courses', adminController.createCourse);
router.get('/courses', adminController.getAllCourses);
router.put('/courses/:courseId/assign-teacher', adminController.assignTeacherToCourse);

// Enrollment
router.post('/enroll', adminController.enrollStudent);
router.get('/courses/:courseId/enrollments', adminController.getCourseEnrollments);

// Notifications (drop-course requests from teachers)
router.get('/notifications', adminController.getNotifications);
router.post('/notifications/:notificationId/resolve', adminController.resolveNotification);

module.exports = router;
