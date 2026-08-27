const router = require('express').Router();
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const teacherController = require('../controllers/teacherController');

router.use(auth, roleCheck('teacher'));

router.get('/courses', teacherController.getMyCourses);

router.post('/session/start', teacherController.startSession);
router.post('/session/:id/end', teacherController.endSession);
router.get('/session/:id/attendance-csv', teacherController.downloadSessionCSV);

router.get('/course/:id/summary-csv', teacherController.downloadCourseSummaryCSV);

router.post('/drop-course-request', teacherController.requestDropCourseEnroll);

module.exports = router;
