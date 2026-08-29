import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../models/models.dart';

/// Central HTTP API client — attaches JWT bearer token to all requests.
class ApiClient {
  final String? token;

  ApiClient({this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthUser> login(String emailOrReg, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'emailOrReg': emailOrReg, 'password': password}),
    );
    _checkError(res);
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createStudent(
      String registrationNo, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/admin/students'),
      headers: _headers,
      body:
          jsonEncode({'registrationNo': registrationNo, 'password': password}),
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTeacher(
      String email, String password, String department) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/admin/teachers'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'department': department,
      }),
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTeachers({String? department}) async {
    final uri = Uri.parse('$kApiBase/api/admin/teachers').replace(
        queryParameters:
            department != null ? {'department': department} : null);
    final res = await http.get(uri, headers: _headers);
    _checkError(res);
    return List<Map<String, dynamic>>.from(
        jsonDecode(res.body) as List<dynamic>);
  }

  Future<Map<String, dynamic>> createClass(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/admin/classes'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<ClassModel>> getAdminClasses() async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/admin/classes'),
      headers: _headers,
    );
    _checkError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((j) => ClassModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> endClass(String classId) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/admin/classes/$classId/end'),
      headers: _headers,
    );
    _checkError(res);
  }

  Future<void> resetPassword(String identifier, String newPassword) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/admin/users/reset-password'),
      headers: _headers,
      body: jsonEncode({'identifier': identifier, 'newPassword': newPassword}),
    );
    _checkError(res);
  }

  // ── Teacher ──────────────────────────────────────────────────────────────

  Future<List<ClassModel>> getTeacherClasses() async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/teacher/classes'),
      headers: _headers,
    );
    _checkError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((j) => ClassModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<SessionModel> startSession({
    required String classId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required int durationSeconds,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/sessions/start'),
      headers: _headers,
      body: jsonEncode({
        'classId': classId,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'durationSeconds': durationSeconds,
      }),
    );
    _checkError(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return SessionModel(
      id: json['id'] as String,
      classId: classId,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      expiresAt: json['expiresAt'] as String?,
      startedAt: json['startedAt'] as String?,
      status: 'ACTIVE',
    );
  }

  Future<void> endSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/sessions/$sessionId/end'),
      headers: _headers,
    );
    _checkError(res);
  }

  Future<Map<String, dynamic>> getSessionRecords(String sessionId) async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/sessions/$sessionId/records'),
      headers: _headers,
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveManualAttendance({
    required String classId,
    required List<Map<String, dynamic>> records,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/sessions/manual'),
      headers: _headers,
      body: jsonEncode({
        'classId': classId,
        'records': records,
      }),
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<EnrolledStudent>> getClassStudents(String classId) async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/classes/$classId/students'),
      headers: _headers,
    );
    _checkError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((j) => EnrolledStudent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addStudentToClass(String classId, String regNo) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/classes/$classId/students'),
      headers: _headers,
      body: jsonEncode({'registrationNo': regNo}),
    );
    _checkError(res);
  }

  Future<void> removeStudentFromClass(String classId, String regNo) async {
    final res = await http.delete(
      Uri.parse('$kApiBase/api/classes/$classId/students/$regNo'),
      headers: _headers,
    );
    _checkError(res);
  }

  Future<AttendanceMatrix> getAttendanceMatrix(String classId) async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/classes/$classId/report/matrix'),
      headers: _headers,
    );
    _checkError(res);
    return AttendanceMatrix.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> getAttendanceCsv(String classId) async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/classes/$classId/report/csv'),
      headers: _headers,
    );
    _checkError(res);
    return res.body;
  }

  // ── Student ──────────────────────────────────────────────────────────────

  Future<List<ClassModel>> getStudentClasses() async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/student/classes'),
      headers: _headers,
    );
    _checkError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((j) => ClassModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getActiveSession(String classId) async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/student/classes/$classId/active-session'),
      headers: _headers,
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimAttendance({
    required String sessionId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String deviceInstallId,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/api/attendance/claim'),
      headers: _headers,
      body: jsonEncode({
        'sessionId': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'deviceInstallId': deviceInstallId,
      }),
    );
    _checkError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<AttendanceHistory>> getAttendanceHistory() async {
    final res = await http.get(
      Uri.parse('$kApiBase/api/student/attendance/history'),
      headers: _headers,
    );
    _checkError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((j) => AttendanceHistory.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  void _checkError(http.Response res) {
    if (res.statusCode >= 400) {
      String message = 'Request failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? message;
      } catch (_) {}
      throw ApiException(message, res.statusCode);
    }
  }
}

/// API error with status code.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
