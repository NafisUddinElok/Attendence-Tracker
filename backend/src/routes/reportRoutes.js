const express = require('express');
const router = express.Router();
const reportController = require('../controllers/reportController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

// Teacher Course Attendance Exports
router.get('/course/:courseId/excel', protect, authorizeRoles('TEACHER'), reportController.exportCourseExcel);
router.get('/course/:courseId/csv', protect, authorizeRoles('TEACHER'), reportController.exportCourseCSV);

module.exports = router;