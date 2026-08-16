const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

// Teacher Session Management
router.post('/session/start', protect, authorizeRoles('TEACHER'), attendanceController.startSession);
router.post('/session/:id/end', protect, authorizeRoles('TEACHER'), attendanceController.endSession);
router.get('/session/:id/live', protect, authorizeRoles('TEACHER'), attendanceController.getLiveSession);

// Student: find the live session for a course (replaces QR scan)
router.get('/session/active/:courseId', protect, authorizeRoles('STUDENT'), attendanceController.getActiveSessionForCourse);

// Student Geofence-Based Verification
router.post('/verify', protect, authorizeRoles('STUDENT'), attendanceController.verifyAttendance);

// Attendance History
router.get('/history/session/:id', protect, attendanceController.getSessionHistory);
router.get('/history/student', protect, authorizeRoles('STUDENT'), attendanceController.getStudentAttendance);

module.exports = router;