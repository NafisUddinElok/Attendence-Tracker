const { Enrollment, Course, Session, Attendance, User } = require('../models');
const { getDistanceInMeters } = require('../utils/haversine');

// GET /student/courses - enrolled active courses
exports.getMyCourses = async (req, res) => {
  const enrollments = await Enrollment.findAll({
    where: { student_id: req.user.id, status: 'active' },
    include: [{ model: Course, include: [{ model: User, as: 'teacher', attributes: ['name'] }] }],
  });
  res.json(enrollments);
};

// GET /student/session/active/:courseId - check if there's a live session for a course
exports.getActiveSession = async (req, res) => {
  const { courseId } = req.params;

  // Confirm student is actually enrolled in this course
  const enrollment = await Enrollment.findOne({
    where: { student_id: req.user.id, course_id: courseId, status: 'active' },
  });
  if (!enrollment) return res.status(403).json({ message: 'Not enrolled in this course' });

  const session = await Session.findOne({ where: { course_id: courseId, status: 'active' } });
  if (!session) return res.status(404).json({ message: 'No active session right now' });

  res.json(session);
};

// POST /student/attendance/mark
// body: { session_id, latitude, longitude }
exports.markAttendance = async (req, res) => {
  try {
    const { session_id, latitude, longitude } = req.body;

    const session = await Session.findOne({ where: { id: session_id, status: 'active' } });
    if (!session) return res.status(404).json({ message: 'Session not active or does not exist' });

    // Confirm enrollment
    const enrollment = await Enrollment.findOne({
      where: { student_id: req.user.id, course_id: session.course_id, status: 'active' },
    });
    if (!enrollment) return res.status(403).json({ message: 'Not enrolled in this course' });

    // Prevent duplicate attendance
    const existing = await Attendance.findOne({ where: { session_id, student_id: req.user.id } });
    if (existing) return res.status(400).json({ message: 'Attendance already marked' });

    const distance = getDistanceInMeters(session.latitude, session.longitude, latitude, longitude);

    if (distance > session.radius_meters) {
      return res.status(403).json({
        message: `You are outside the allowed range (${distance.toFixed(1)}m away, limit ${session.radius_meters}m)`,
      });
    }

    const attendance = await Attendance.create({
      session_id,
      student_id: req.user.id,
      student_latitude: latitude,
      student_longitude: longitude,
      distance_meters: distance,
      status: 'present',
    });

    res.status(201).json({ message: 'Attendance marked successfully', attendance });
  } catch (err) {
    res.status(500).json({ message: 'Failed to mark attendance', error: err.message });
  }
};
