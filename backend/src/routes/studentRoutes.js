const router = require('express').Router();
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const studentController = require('../controllers/studentController');

router.use(auth, roleCheck('student'));

router.get('/courses', studentController.getMyCourses);
router.get('/session/active/:courseId', studentController.getActiveSession);
router.post('/attendance/mark', studentController.markAttendance);

module.exports = router;
