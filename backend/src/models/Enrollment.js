const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Enrollment = sequelize.define('Enrollment', {
  status: { type: DataTypes.ENUM('active', 'dropped'), defaultValue: 'active' },
  enrolled_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  dropped_at: { type: DataTypes.DATE, allowNull: true },
}, {
  tableName: 'enrollments',
  underscored: true,
  timestamps: false,
});

module.exports = Enrollment;
