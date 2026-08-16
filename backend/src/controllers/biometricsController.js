const biometricsService = require('../modules/biometrics/biometrics.service');

exports.enrollFace = async (req, res) => {
  const { deviceId, embeddings } = req.body;
  const studentId = req.user.id;
  try {
    const result = await biometricsService.enrollFace({ studentId, deviceId, embeddings });
    res.status(200).json({ message: 'Face enrolled and device bound.', enrolledAt: result.enrolledAt });
  } catch (error) {
    if (!(error && error.name === 'AppError')) {
      console.error('Enroll Face Error:', error);
    }
    throw error;
  }
};
