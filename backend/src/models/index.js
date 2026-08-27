const sequelize = require('../config/db');
const User = require('./User');
const Course = require('./Course');
const Enrollment = require('./Enrollment');
const Session = require('./Session');
const Attendance = require('./Attendance');
const Notification = require('./Notification');

// ---------- Course <-> Teacher (User) ----------
Course.belongsTo(User, { as: 'teacher', foreignKey: 'teacher_id' });
User.hasMany(Course, { as: 'courses', foreignKey: 'teacher_id' });

// ---------- Enrollment (Course <-> Student) ----------
Course.hasMany(Enrollment, { foreignKey: 'course_id', onDelete: 'CASCADE' });
Enrollment.belongsTo(Course, { foreignKey: 'course_id' });

User.hasMany(Enrollment, { as: 'enrollments', foreignKey: 'student_id', onDelete: 'CASCADE' });
Enrollment.belongsTo(User, { as: 'student', foreignKey: 'student_id' });

// ---------- Session ----------
Course.hasMany(Session, { foreignKey: 'course_id', onDelete: 'CASCADE' });
Session.belongsTo(Course, { foreignKey: 'course_id' });

User.hasMany(Session, { as: 'sessionsHeld', foreignKey: 'teacher_id' });
Session.belongsTo(User, { as: 'teacher', foreignKey: 'teacher_id' });

// ---------- Attendance ----------
Session.hasMany(Attendance, { foreignKey: 'session_id', onDelete: 'CASCADE' });
Attendance.belongsTo(Session, { foreignKey: 'session_id' });

User.hasMany(Attendance, { as: 'attendanceRecords', foreignKey: 'student_id' });
Attendance.belongsTo(User, { as: 'student', foreignKey: 'student_id' });

// ---------- Notification ----------
User.hasMany(Notification, { as: 'sentNotifications', foreignKey: 'sender_id' });
Notification.belongsTo(User, { as: 'sender', foreignKey: 'sender_id' });

User.hasMany(Notification, { as: 'receivedNotifications', foreignKey: 'receiver_id' });
Notification.belongsTo(User, { as: 'receiver', foreignKey: 'receiver_id' });

Course.hasMany(Notification, { foreignKey: 'course_id', onDelete: 'CASCADE' });
Notification.belongsTo(Course, { foreignKey: 'course_id' });

module.exports = {
  sequelize,
  User,
  Course,
  Enrollment,
  Session,
  Attendance,
  Notification,
};
