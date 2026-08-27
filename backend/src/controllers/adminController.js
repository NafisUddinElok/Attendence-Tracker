const bcrypt = require('bcryptjs');
const { User, Course, Enrollment, Notification } = require('../models');

// ---------------- Teachers ----------------
exports.createTeacher = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;
    const hashedPassword = await bcrypt.hash(password, 10);
    const teacher = await User.create({ name, email, password: hashedPassword, role: 'teacher', phone });
    res.status(201).json({ message: 'Teacher created', teacher });
  } catch (err) {
    res.status(500).json({ message: 'Failed to create teacher', error: err.message });
  }
};

exports.getAllTeachers = async (req, res) => {
  const teachers = await User.findAll({ where: { role: 'teacher' } });
  res.json(teachers);
};

// ---------------- Students ----------------
exports.createStudent = async (req, res) => {
  try {
    const { name, email, password, registration_number, phone } = req.body;
    const hashedPassword = await bcrypt.hash(password, 10);
    const student = await User.create({
      name, email, password: hashedPassword, role: 'student', registration_number, phone,
    });
    res.status(201).json({ message: 'Student created', student });
  } catch (err) {
    res.status(500).json({ message: 'Failed to create student', error: err.message });
  }
};

exports.getAllStudents = async (req, res) => {
  const students = await User.findAll({ where: { role: 'student' } });
  res.json(students);
};

// ---------------- Courses ----------------
exports.createCourse = async (req, res) => {
  try {
    const { course_name, course_code, teacher_id } = req.body;
    const course = await Course.create({ course_name, course_code, teacher_id });
    res.status(201).json({ message: 'Course created', course });
  } catch (err) {
    res.status(500).json({ message: 'Failed to create course', error: err.message });
  }
};

exports.getAllCourses = async (req, res) => {
  const courses = await Course.findAll({
    include: [{ model: User, as: 'teacher', attributes: ['id', 'name', 'email'] }],
  });
  res.json(courses);
};

// Assign / change which teacher teaches a course
exports.assignTeacherToCourse = async (req, res) => {
  try {
    const { courseId } = req.params;
    const { teacher_id } = req.body;
    const course = await Course.findByPk(courseId);
    if (!course) return res.status(404).json({ message: 'Course not found' });

    course.teacher_id = teacher_id;
    await course.save();
    res.json({ message: 'Teacher assigned to course', course });
  } catch (err) {
    res.status(500).json({ message: 'Failed to assign teacher', error: err.message });
  }
};

// ---------------- Enrollment ----------------
// Manually enroll a student into a course (used for both normal enroll + drop-course re-enroll)
exports.enrollStudent = async (req, res) => {
  try {
    const { course_id, student_id } = req.body;

    const [enrollment, created] = await Enrollment.findOrCreate({
      where: { course_id, student_id },
      defaults: { status: 'active' },
    });

    if (!created) {
      enrollment.status = 'active';
      enrollment.dropped_at = null;
      await enrollment.save();
    }

    res.status(201).json({ message: 'Student enrolled successfully', enrollment });
  } catch (err) {
    res.status(500).json({ message: 'Enrollment failed', error: err.message });
  }
};

exports.getCourseEnrollments = async (req, res) => {
  const { courseId } = req.params;
  const enrollments = await Enrollment.findAll({
    where: { course_id: courseId, status: 'active' },
    include: [{ model: User, as: 'student', attributes: ['id', 'name', 'registration_number', 'email'] }],
  });
  res.json(enrollments);
};

// ---------------- Notifications (drop-course requests from teachers) ----------------
exports.getNotifications = async (req, res) => {
  const notifications = await Notification.findAll({
    where: { status: 'unread' },
    include: [
      { model: User, as: 'sender', attributes: ['id', 'name', 'email'] },
      { model: Course, attributes: ['id', 'course_name', 'course_code'] },
    ],
    order: [['created_at', 'DESC']],
  });
  res.json(notifications);
};

// Admin resolves a drop-course notification: finds student by registration number
// and enrolls them into the course mentioned in the notification.
exports.resolveNotification = async (req, res) => {
  try {
    const { notificationId } = req.params;
    const notification = await Notification.findByPk(notificationId);
    if (!notification) return res.status(404).json({ message: 'Notification not found' });

    const student = await User.findOne({
      where: { registration_number: notification.student_registration_number, role: 'student' },
    });
    if (!student) return res.status(404).json({ message: 'Student with this registration number not found' });

    await Enrollment.findOrCreate({
      where: { course_id: notification.course_id, student_id: student.id },
      defaults: { status: 'active' },
    });

    notification.status = 'read';
    await notification.save();

    res.json({ message: 'Student enrolled and notification resolved' });
  } catch (err) {
    res.status(500).json({ message: 'Failed to resolve notification', error: err.message });
  }
};
