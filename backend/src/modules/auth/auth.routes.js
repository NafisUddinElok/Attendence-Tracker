const router = require('express').Router();
const ctrl = require('./auth.controller');
const validate = require('../../middlewares/validate');
const { protect } = require('../../middlewares/authMiddleware');
const dto = require('./auth.dto');

router.post('/register/student', validate(dto.studentRegister), ctrl.registerStudent);
router.post('/register/teacher', validate(dto.teacherRegister), ctrl.registerTeacher);
router.post('/login', validate(dto.login), ctrl.login);
router.post('/refresh', validate(dto.refresh), ctrl.refresh);
router.post('/logout', validate(dto.logout), ctrl.logout);
router.get('/me', protect, ctrl.me);

module.exports = router;
