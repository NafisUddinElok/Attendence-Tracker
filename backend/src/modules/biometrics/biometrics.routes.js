const router = require('express').Router();
const ctrl = require('../../controllers/biometricsController');
const { protect, requireRole } = require('../../middlewares/authMiddleware');

router.post('/enroll-face', protect, requireRole('student'), ctrl.enrollFace);

module.exports = router;
