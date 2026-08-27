const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Attendance = sequelize.define('Attendance', {
  marked_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  student_latitude: { type: DataTypes.DOUBLE, allowNull: false },
  student_longitude: { type: DataTypes.DOUBLE, allowNull: false },
  distance_meters: { type: DataTypes.DOUBLE, allowNull: true },
  status: { type: DataTypes.STRING(20), defaultValue: 'present' },
}, {
  tableName: 'attendance',
  underscored: true,
  timestamps: false,
});

module.exports = Attendance;
