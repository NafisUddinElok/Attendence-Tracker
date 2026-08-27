const { Op } = require('sequelize');
const path = require('path');
const {
  Course, Session, Attendance, Enrollment, User, Notification,
} = require('../models');
const { generateCSV } = require('../utils/csvGenerator');

// GET /teacher/courses - courses assigned to the logged-in teacher
exports.getMyCourses = async (req, res) => {
  const courses = await Course.findAll({ where: { teacher_id: req.user.id } });
  res.json(courses);
};

// POST /teacher/session/start
// body: { course_id, latitude, longitude, radius_meters }
exports.startSession = async (req, res) => {
  try {
    const { course_id, latitude, longitude, radius_meters } = req.body;

    const course = await Course.findOne({ where: { id: course_id, teacher_id: req.user.id } });
    if (!course) return res.status(403).json({ message: 'You do not teach this course' });

    const session = await Session.create({
      course_id,
      teacher_id: req.user.id,
      session_date: new Date().toISOString().slice(0, 10),
      latitude,
      longitude,
      radius_meters: radius_meters || 100,
      status: 'active',
    });

    res.status(201).json({ message: 'Session started', session });
  } catch (err) {
    res.status(500).json({ message: 'Failed to start session', error: err.message });
  }
};

// POST /teacher/session/:id/end
// Ends session AND generates the attendance CSV for that class
exports.endSession = async (req, res) => {
  try {
    const { id } = req.params;
    const session = await Session.findOne({ where: { id, teacher_id: req.user.id } });
    if (!session) return res.status(404).json({ message: 'Session not found' });

    session.status = 'ended';
    session.end_time = new Date();

    // Fetch all attendance for this session
    const attendanceRecords = await Attendance.findAll({
      where: { session_id: id },
      include: [{ model: User, as: 'student', attributes: ['name', 'registration_number', 'email'] }],
      order: [['marked_at', 'ASC']],
    });

    const rows = attendanceRecords.map((rec) => ({
      registration_number: rec.student.registration_number,
      name: rec.student.name,
      marked_at: rec.marked_at,
      status: rec.status,
      distance_meters: rec.distance_meters?.toFixed(2),
    }));

    const fileName = `session_${session.id}_${session.session_date}.csv`;
    const filePath = generateCSV(
      rows,
      ['registration_number', 'name', 'marked_at', 'status', 'distance_meters'],
      fileName
    );

    session.csv_file_path = filePath;
    await session.save();

    res.json({ message: 'Session ended, attendance CSV generated', session, csv_file: fileName });
  } catch (err) {
    res.status(500).json({ message: 'Failed to end session', error: err.message });
  }
};

// GET /teacher/session/:id/attendance-csv  - download CSV for one class
exports.downloadSessionCSV = async (req, res) => {
  const { id } = req.params;
  const session = await Session.findOne({ where: { id, teacher_id: req.user.id } });
  if (!session || !session.csv_file_path) {
    return res.status(404).json({ message: 'CSV not found for this session' });
  }
  res.download(session.csv_file_path);
};

// GET /teacher/course/:id/summary-csv
// Student-wise full attendance history for a course:
// each row = one student, with total classes held, total present, and which dates they attended
exports.downloadCourseSummaryCSV = async (req, res) => {
  try {
    const { id: courseId } = req.params;

    const course = await Course.findOne({ where: { id: courseId, teacher_id: req.user.id } });
    if (!course) return res.status(403).json({ message: 'You do not teach this course' });

    // All sessions ever held for this course
    const sessions = await Session.findAll({ where: { course_id: courseId, status: 'ended' } });
    const totalSessions = sessions.length;
    const sessionDates = sessions.map((s) => s.session_date).join('; ');

    // Active enrolled students
    const enrollments = await Enrollment.findAll({
      where: { course_id: courseId, status: 'active' },
      include: [{ model: User, as: 'student', attributes: ['id', 'name', 'registration_number'] }],
    });

    const rows = [];
    for (const enr of enrollments) {
      const studentId = enr.student.id;

      const presentCount = await Attendance.count({
        where: { student_id: studentId },
        include: [{
          model: Session,
          where: { course_id: courseId },
          attributes: [],
        }],
      });

      rows.push({
        registration_number: enr.student.registration_number,
        name: enr.student.name,
        total_classes_held: totalSessions,
        total_present: presentCount,
        attendance_percentage: totalSessions > 0
          ? ((presentCount / totalSessions) * 100).toFixed(1) + '%'
          : '0%',
        class_dates_held: sessionDates,
      });
    }

    const fileName = `course_${courseId}_summary.csv`;
    const filePath = generateCSV(
      rows,
      ['registration_number', 'name', 'total_classes_held', 'total_present', 'attendance_percentage', 'class_dates_held'],
      fileName
    );

    res.download(filePath);
  } catch (err) {
    res.status(500).json({ message: 'Failed to generate summary CSV', error: err.message });
  }
};

// POST /teacher/drop-course-request
// Teacher manually adds a student's registration number (student dropped a course, now taking this one)
// This creates a notification for the admin instead of enrolling directly.
exports.requestDropCourseEnroll = async (req, res) => {
  try {
    const { course_id, student_registration_number, message } = req.body;

    const course = await Course.findOne({ where: { id: course_id, teacher_id: req.user.id } });
    if (!course) return res.status(403).json({ message: 'You do not teach this course' });

    const notification = await Notification.create({
      type: 'drop_course_enroll_request',
      sender_id: req.user.id,
      course_id,
      student_registration_number,
      message: message || `Teacher requests enrollment for reg no. ${student_registration_number} into ${course.course_name}`,
      status: 'unread',
    });

    res.status(201).json({ message: 'Request sent to admin', notification });
  } catch (err) {
    res.status(500).json({ message: 'Failed to send request', error: err.message });
  }
};
