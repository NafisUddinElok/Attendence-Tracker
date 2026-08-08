// lib/attendance_service.dart
//
// Flutter client for the geofencing attendance backend.
//
// Dependencies (add to pubspec.yaml):
//   http: ^1.2.0
//   geolocator: ^13.0.0
//   flutter_secure_storage: ^9.2.0
//   path_provider: ^2.1.0   (added for CSV download — see downloadAttendanceCsv)
//   share_plus: ^10.0.0     (added for CSV download — opens the native share/save sheet)
//
// Android setup (android/app/src/main/AndroidManifest.xml):
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//
// iOS setup (ios/Runner/Info.plist):
//   <key>NSLocationWhenInUseUsageDescription</key>
//   <string>We use your location to verify classroom attendance.</string>

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LoginResult {
  final bool success;
  final String message;
  final String? name;
  LoginResult({required this.success, required this.message, this.name});
}

class RegisterResult {
  final bool success;
  final String message;
  RegisterResult({required this.success, required this.message});
}

class AttendanceService {
  // Point this at your deployed server. For local testing on a physical
  // device, "localhost" won't work — use your machine's LAN IP instead
  // (e.g. http://192.168.1.10:3000). Android emulator uses 10.0.2.2.
  static const String baseUrl = 'http://192.168.0.151:3000';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role'; // 'student' or 'teacher'
  static const _nameKey = 'auth_name';

  // --- Student registration ---------------------------------------------------
  static Future<RegisterResult> register(String studentCode, String name, String password) {
    return _postRegister('$baseUrl/register', {
      'studentCode': studentCode,
      'name': name,
      'password': password,
    });
  }

  // --- Teacher registration ----------------------------------------------------
  static Future<RegisterResult> teacherRegister(String teacherCode, String name, String password) {
    return _postRegister('$baseUrl/teacher-register', {
      'teacherCode': teacherCode,
      'name': name,
      'password': password,
    });
  }

  static Future<RegisterResult> _postRegister(String url, Map<String, String> body) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return RegisterResult(success: false, message: 'Unexpected response from server.');
      }

      return RegisterResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? 'Something went wrong.',
      );
    } on TimeoutException {
      return RegisterResult(
        success: false,
        message: 'Could not reach the server. Check that the backend is running and '
            'your phone is on the same WiFi network as $baseUrl.',
      );
    } on SocketException catch (e) {
      return RegisterResult(
        success: false,
        message: 'Network error (${e.message}). Check the server address and WiFi connection.',
      );
    } catch (e) {
      return RegisterResult(success: false, message: 'Unexpected error: $e');
    }
  }

  /// Logs in a student and stores the JWT securely (Keychain on iOS, Keystore
  /// on Android). Never hangs indefinitely and never throws — network/timeout
  /// failures come back as a LoginResult with a message you can show the user.
  static Future<LoginResult> login(String studentCode, String password) {
    return _postLogin(
      '$baseUrl/login',
      {'studentCode': studentCode, 'password': password},
      role: 'student',
    );
  }

  /// Logs in a teacher. Same shape as [login] but hits /teacher-login and
  /// stores role: 'teacher' so the rest of the app knows which home
  /// screen and which API surface (course/session management) to use.
  static Future<LoginResult> teacherLogin(String teacherCode, String password) {
    return _postLogin(
      '$baseUrl/teacher-login',
      {'teacherCode': teacherCode, 'password': password},
      role: 'teacher',
    );
  }

  static Future<LoginResult> _postLogin(String url, Map<String, String> body, {required String role}) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return LoginResult(success: false, message: 'Unexpected response from server.');
      }

      if (response.statusCode != 200 || data['success'] != true || data['token'] == null) {
        return LoginResult(
          success: false,
          message: data['message'] as String? ?? 'Invalid code or password.',
        );
      }

      final name = data['name'] as String?;
      await _storage.write(key: _tokenKey, value: data['token'] as String);
      await _storage.write(key: _roleKey, value: role);
      if (name != null) await _storage.write(key: _nameKey, value: name);

      return LoginResult(success: true, message: 'Logged in.', name: name);
    } on TimeoutException {
      return LoginResult(
        success: false,
        message: 'Could not reach the server. Check that the backend is running and '
            'your phone is on the same WiFi network as $baseUrl.',
      );
    } on SocketException catch (e) {
      return LoginResult(
        success: false,
        message: 'Network error (${e.message}). Check the server address and WiFi connection.',
      );
    } catch (e) {
      return LoginResult(success: false, message: 'Unexpected error: $e');
    }
  }

  static Future<String?> _getToken() => _storage.read(key: _tokenKey);

  /// Returns 'student' or 'teacher' for the currently logged-in user, or
  /// null if no one is logged in. Screens use this to decide routing —
  /// never trust a role passed around in memory alone, since it should
  /// always match what's actually stored alongside the token.
  static Future<String?> getRole() => _storage.read(key: _roleKey);

  static Future<String?> getName() => _storage.read(key: _nameKey);

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _nameKey);
  }

  /// Result of an attendance attempt, surfaced to the UI.
  /// [faceVerified] must come from a completed FaceLivenessScreen check —
  /// the backend rejects the request outright if this isn't true.
  // --- Teacher: courses -------------------------------------------------------
  static Future<CoursesResult> getMyCourses() async {
    return _authGetCourses('$baseUrl/courses/mine');
  }

  static Future<CourseActionResult> createCourse(String courseCode, String courseName) async {
    final token = await _getToken();
    if (token == null) {
      return CourseActionResult(success: false, message: 'Please log in again.');
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/courses/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'courseCode': courseCode, 'courseName': courseName}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CourseActionResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? (data['success'] == true ? 'Course created.' : 'Something went wrong.'),
        courseId: data['courseId'] as int?,
      );
    } on TimeoutException {
      return CourseActionResult(success: false, message: 'Could not reach the server.');
    } on SocketException catch (e) {
      return CourseActionResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return CourseActionResult(success: false, message: 'Unexpected error: $e');
    }
  }

  static Future<CoursesResult> _authGetCourses(String url) async {
    final token = await _getToken();
    if (token == null) {
      return CoursesResult(success: false, message: 'Please log in again.', courses: []);
    }
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return CoursesResult(
          success: false,
          message: data['message'] as String? ?? 'Could not load courses.',
          courses: [],
        );
      }
      final list = (data['courses'] as List<dynamic>? ?? [])
          .map((c) => Course.fromJson(c as Map<String, dynamic>))
          .toList();
      return CoursesResult(success: true, message: '', courses: list);
    } on TimeoutException {
      return CoursesResult(success: false, message: 'Could not reach the server.', courses: []);
    } on SocketException catch (e) {
      return CoursesResult(success: false, message: 'Network error (${e.message}).', courses: []);
    } catch (e) {
      return CoursesResult(success: false, message: 'Unexpected error: $e', courses: []);
    }
  }

  // --- Student: browse / enroll in courses --------------------------------------
  static Future<CoursesResult> getAllCourses() async {
    return _authGetCourses('$baseUrl/courses/all');
  }

  static Future<CoursesResult> getEnrolledCourses() async {
    return _authGetCourses('$baseUrl/courses/enrolled');
  }

  static Future<CourseActionResult> enrollCourse(int courseId) async {
    final token = await _getToken();
    if (token == null) {
      return CourseActionResult(success: false, message: 'Please log in again.');
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/courses/enroll'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'courseId': courseId}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CourseActionResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? (data['success'] == true ? 'Enrolled.' : 'Something went wrong.'),
      );
    } on TimeoutException {
      return CourseActionResult(success: false, message: 'Could not reach the server.');
    } on SocketException catch (e) {
      return CourseActionResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return CourseActionResult(success: false, message: 'Unexpected error: $e');
    }
  }

  // --- Student: find the active session for an enrolled course -------------------
  /// Hits /sessions/active?courseId=... so the student app never has to know
  /// a sessionId in advance — the backend tells us which class_sessions row
  /// (if any) is currently open for this course.
  static Future<ActiveSessionResult> getActiveSession(int courseId) async {
    final token = await _getToken();
    if (token == null) {
      return ActiveSessionResult(success: false, message: 'Please log in again.');
    }
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/sessions/active?courseId=$courseId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return ActiveSessionResult(
          success: false,
          message: data['message'] as String? ?? 'No active session for this course right now.',
        );
      }
      return ActiveSessionResult(
        success: true,
        message: '',
        sessionId: data['sessionId'] as int?,
        label: data['label'] as String?,
        endsAt: data['endsAt'] as String?,
      );
    } on TimeoutException {
      return ActiveSessionResult(success: false, message: 'Could not reach the server.');
    } on SocketException catch (e) {
      return ActiveSessionResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return ActiveSessionResult(success: false, message: 'Unexpected error: $e');
    }
  }

  // --- Teacher: start a geofenced session for a course -------------------------
  /// Captures the teacher's current GPS position and uses it as the geofence
  /// center. [radiusMeters] and [durationMinutes] control how far students
  /// may be and how long the session stays active.
  static Future<SessionStartResult> startSession({
    required int courseId,
    required int radiusMeters,
    required int durationMinutes,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SessionStartResult(success: false, message: 'Please log in again.');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return SessionStartResult(success: false, message: 'Please enable location services.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return SessionStartResult(success: false, message: 'Location permission is required.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return SessionStartResult(
        success: false,
        message: 'Location permission permanently denied. Enable it from Settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/sessions/start'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'courseId': courseId,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'radiusMeters': radiusMeters,
              'durationMinutes': durationMinutes,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SessionStartResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? (data['success'] == true ? 'Session started.' : 'Something went wrong.'),
        sessionId: data['sessionId'] as int?,
        endsAt: data['endsAt'] as String?,
      );
    } on TimeoutException {
      return SessionStartResult(success: false, message: 'Could not reach the server.');
    } on SocketException catch (e) {
      return SessionStartResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return SessionStartResult(success: false, message: 'Unexpected error: $e');
    }
  }

  static Future<AttendanceResult> markAttendance(int sessionId, {required bool faceVerified}) async {
    final token = await _getToken();
    if (token == null) {
      return AttendanceResult(success: false, message: 'Please log in again.');
    }

    if (!faceVerified) {
      return AttendanceResult(success: false, message: 'Face verification is required.');
    }

    // 1. Make sure location services + permission are actually available.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AttendanceResult(success: false, message: 'Please enable location services.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return AttendanceResult(success: false, message: 'Location permission is required.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return AttendanceResult(
        success: false,
        message: 'Location permission permanently denied. Enable it from Settings.',
      );
    }

    // 2. Get current position. On Android, Position.isMocked reflects the OS's
    // real mock-location-provider check — this is what we forward to the
    // server. On iOS, isMocked is always false (no reliable native signal);
    // treat that as a known platform limitation, not a guarantee.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 3. Call the backend.
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/geofencing/mark-attendance'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'sessionId': sessionId,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'isMocked': position.isMocked,
              'faceVerified': faceVerified,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AttendanceResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? 'Unknown error.',
      );
    } on TimeoutException {
      return AttendanceResult(
        success: false,
        message: 'Could not reach the server. Check your WiFi connection and that the backend is running.',
      );
    } on SocketException catch (e) {
      return AttendanceResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return AttendanceResult(success: false, message: 'Unexpected error: $e');
    }
  }
  // --- Teacher: attendance history for a course (JSON, for an in-app table) -----
  static Future<AttendanceHistoryResult> getCourseAttendance(int courseId) async {
    final token = await _getToken();
    if (token == null) {
      return AttendanceHistoryResult(success: false, message: 'Please log in again.', records: []);
    }
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$courseId/attendance'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return AttendanceHistoryResult(
          success: false,
          message: data['message'] as String? ?? 'Could not load attendance.',
          records: [],
        );
      }
      final records = (data['records'] as List<dynamic>? ?? [])
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      return AttendanceHistoryResult(success: true, message: '', records: records);
    } on TimeoutException {
      return AttendanceHistoryResult(success: false, message: 'Could not reach the server.', records: []);
    } on SocketException catch (e) {
      return AttendanceHistoryResult(success: false, message: 'Network error (${e.message}).', records: []);
    } catch (e) {
      return AttendanceHistoryResult(success: false, message: 'Unexpected error: $e', records: []);
    }
  }

  // --- Student: their own attendance history for a course -----------------------
  static Future<AttendanceHistoryResult> getMyAttendance(int courseId) async {
    final token = await _getToken();
    if (token == null) {
      return AttendanceHistoryResult(success: false, message: 'Please log in again.', records: []);
    }
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$courseId/my-attendance'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return AttendanceHistoryResult(
          success: false,
          message: data['message'] as String? ?? 'Could not load attendance.',
          records: [],
        );
      }
      final records = (data['records'] as List<dynamic>? ?? [])
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      return AttendanceHistoryResult(success: true, message: '', records: records);
    } on TimeoutException {
      return AttendanceHistoryResult(success: false, message: 'Could not reach the server.', records: []);
    } on SocketException catch (e) {
      return AttendanceHistoryResult(success: false, message: 'Network error (${e.message}).', records: []);
    } catch (e) {
      return AttendanceHistoryResult(success: false, message: 'Unexpected error: $e', records: []);
    }
  }

  // --- Teacher: download attendance CSV for a course -----------------------------
  /// Fetches /courses/:id/attendance-export with the auth header (a plain
  /// browser link can't attach that), writes it to the app's temp directory,
  /// then hands it to the OS share sheet so the teacher can save it to
  /// Files/Drive or send it directly — CSV downloads have no fixed
  /// destination on mobile the way they do on desktop, so "share" is the
  /// right primitive here rather than "save".
  static Future<CsvDownloadResult> downloadAttendanceCsv(int courseId, String courseCode) async {
    final token = await _getToken();
    if (token == null) {
      return CsvDownloadResult(success: false, message: 'Please log in again.');
    }
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$courseId/attendance-export'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        Map<String, dynamic>? data;
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          // Body wasn't JSON (e.g. a plain-text error) — fall through to default message.
        }
        return CsvDownloadResult(
          success: false,
          message: data?['message'] as String? ?? 'Could not export attendance.',
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$courseCode-attendance.csv');
      await file.writeAsBytes(response.bodyBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '$courseCode attendance export',
        ),
      );

      return CsvDownloadResult(success: true, message: 'CSV ready to save or send.');
    } on TimeoutException {
      return CsvDownloadResult(success: false, message: 'Could not reach the server.');
    } on SocketException catch (e) {
      return CsvDownloadResult(success: false, message: 'Network error (${e.message}).');
    } catch (e) {
      return CsvDownloadResult(success: false, message: 'Unexpected error: $e');
    }
  }
}

class AttendanceResult {
  final bool success;
  final String message;
  AttendanceResult({required this.success, required this.message});
}

class Course {
  final int id;
  final String courseCode;
  final String courseName;
  Course({required this.id, required this.courseCode, required this.courseName});

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as int,
        courseCode: json['course_code'] as String,
        courseName: json['course_name'] as String,
      );
}

class CoursesResult {
  final bool success;
  final String message;
  final List<Course> courses;
  CoursesResult({required this.success, required this.message, required this.courses});
}

class CourseActionResult {
  final bool success;
  final String message;
  final int? courseId;
  CourseActionResult({required this.success, required this.message, this.courseId});
}

class SessionStartResult {
  final bool success;
  final String message;
  final int? sessionId;
  final String? endsAt;
  SessionStartResult({required this.success, required this.message, this.sessionId, this.endsAt});
}

class AttendanceRecord {
  final String? studentCode; // null on the student's own history (redundant there)
  final String? studentName; // null on the student's own history (redundant there)
  final String sessionLabel;
  final String markedAt;
  final double distanceMeters;

  AttendanceRecord({
    this.studentCode,
    this.studentName,
    required this.sessionLabel,
    required this.markedAt,
    required this.distanceMeters,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        studentCode: json['student_code'] as String?,
        studentName: json['name'] as String?,
        sessionLabel: json['session_label'] as String,
        markedAt: json['marked_at'] as String,
        distanceMeters: (json['distance_meters'] as num).toDouble(),
      );
}

class AttendanceHistoryResult {
  final bool success;
  final String message;
  final List<AttendanceRecord> records;
  AttendanceHistoryResult({required this.success, required this.message, required this.records});
}

class CsvDownloadResult {
  final bool success;
  final String message;
  CsvDownloadResult({required this.success, required this.message});
}

class ActiveSessionResult {
  final bool success;
  final String message;
  final int? sessionId;
  final String? label;
  final String? endsAt;
  ActiveSessionResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.label,
    this.endsAt,
  });
}