const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

router.use(protect);

// ---------------- TEACHER ROUTES ----------------
// 1. Start Live Session (generates rolling secret, center GPS, BLE UUID)
router.post('/session/start', authorizeRoles('TEACHER'), attendanceController.startSession);

// 2. End Live Session
router.post('/session/:sessionId/end', authorizeRoles('TEACHER'), attendanceController.endSession);

// 3. Get Live Attendees count & list
router.get('/session/:sessionId/live', authorizeRoles('TEACHER'), attendanceController.getSessionLiveStats);

// 4. Download CSV Sheet
router.get('/export-csv/:courseId', authorizeRoles('TEACHER'), attendanceController.exportAttendanceCSV);

// ---------------- STUDENT ROUTES ----------------
// 5. Submit & Verify 5-Step Attendance
router.post('/verify', authorizeRoles('STUDENT'), attendanceController.verifyAndMarkAttendance);

module.exports = router;