const express = require('express');
const router = express.Router();
const sessionController = require('../controllers/sessionController');
const { protect, authorizeRoles } = require('../middlewares/authMiddleware');

// টিচারদের জন্য সুরক্ষিত লাইভ সেশন রাউটস
router.post('/start', protect, authorizeRoles('TEACHER'), sessionController.startSession);
router.post('/', protect, authorizeRoles('TEACHER'), sessionController.startSession);
router.get('/:sessionId/token', protect, sessionController.getDynamicQrToken);
router.post('/:sessionId/end', protect, authorizeRoles('TEACHER'), sessionController.endSession);

module.exports = router;