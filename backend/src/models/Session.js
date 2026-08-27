const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Session = sequelize.define('Session', {
  session_date: { type: DataTypes.DATEONLY, allowNull: false },
  start_time: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  end_time: { type: DataTypes.DATE, allowNull: true },
  latitude: { type: DataTypes.DOUBLE, allowNull: false },
  longitude: { type: DataTypes.DOUBLE, allowNull: false },
  radius_meters: { type: DataTypes.INTEGER, defaultValue: 100 },
  status: { type: DataTypes.ENUM('active', 'ended'), defaultValue: 'active' },
  csv_file_path: { type: DataTypes.STRING(255), allowNull: true },
}, {
  tableName: 'sessions',
  underscored: true,
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false,
});

module.exports = Session;
