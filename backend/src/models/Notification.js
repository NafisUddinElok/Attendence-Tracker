const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Notification = sequelize.define('Notification', {
  type: { type: DataTypes.ENUM('drop_course_enroll_request', 'general'), defaultValue: 'general' },
  student_registration_number: { type: DataTypes.STRING(50), allowNull: true },
  message: { type: DataTypes.TEXT, allowNull: true },
  status: { type: DataTypes.ENUM('unread', 'read'), defaultValue: 'unread' },
}, {
  tableName: 'notifications',
  underscored: true,
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false,
});

module.exports = Notification;
