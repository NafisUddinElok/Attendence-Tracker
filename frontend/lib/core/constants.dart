import 'package:flutter/foundation.dart';

/// Dynamic API base URL:
/// - Real Android Phone connects to Mac via local Wi-Fi IP: 10.201.42.71
/// - Web, macOS, iOS connect via localhost
String get kApiBase {
  if (kIsWeb) return 'http://localhost:8080';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.201.42.71:8080';
  }
  return 'http://localhost:8080';
}

/// Department code → name mapping (mirrors backend reg_parser.dart)
const Map<String, String> kDepartmentMap = {
  '831': 'Software Engineering',
  '331': 'Computer Science & Engineering',
  '131': 'Electrical & Electronic Engineering',
  '231': 'Civil Engineering',
  '431': 'Mechanical Engineering',
  '531': 'Chemical Engineering',
  '631': 'Industrial & Production Engineering',
  '731': 'Architecture',
};

const List<String> kDepartments = [
  'Software Engineering',
  'Computer Science & Engineering',
  'Electrical & Electronic Engineering',
  'Civil Engineering',
  'Mechanical Engineering',
  'Chemical Engineering',
  'Industrial & Production Engineering',
  'Architecture',
];

const List<String> kSemesters = [
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
];

/// Role constants
const String kRoleAdmin = 'ADMIN';
const String kRoleTeacher = 'TEACHER';
const String kRoleStudent = 'STUDENT';

/// Token storage key
const String kTokenKey = 'auth_token';
const String kUserKey = 'user_data';

/// Geofence radius range
const double kRadiusMin = 20.0;
const double kRadiusMax = 100.0;
const double kRadiusDefault = 30.0;

/// Session duration options (seconds)
const List<int> kSessionDurations = [30, 60, 120, 300, 600];
