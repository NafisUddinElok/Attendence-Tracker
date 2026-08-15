const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');




// router.post('/register/student', authController.registerStudent);
// router.post('/register/teacher', authController.registerTeacher);
router.post('/register', authController.register);
router.post('/login', authController.login);

// Mount biometric registration route
router.post(
  '/register-biometrics',
  protect,
  authorizeRoles('STUDENT'),
  authController.registerBiometrics
);

module.exports = router;