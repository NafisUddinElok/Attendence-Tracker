const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// router.post('/register/student', authController.registerStudent);
// router.post('/register/teacher', authController.registerTeacher);
router.post('/register', authController.register);
router.post('/login', authController.login);

module.exports = router;