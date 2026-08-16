/// Centralised backend endpoints.
///
/// `baseUrl` is resolved at *compile time* from a `--dart-define` flag, so
/// the same APK can target a local emulator, a staging Render deploy, or a
/// production Render deploy by changing only the build command — no code
/// edits required.
///
/// Examples:
/// ```
///   # Android emulator hitting a local Node server
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///
///   # Debug build pointing at the Render deploy
///   flutter run --dart-define=API_BASE_URL=https://attendance-api.onrender.com
///
///   # Release APK pointing at Render
///   flutter build apk --release \
///     --dart-define=API_BASE_URL=https://attendance-api.onrender.com
/// ```
///
/// On Android the emulator's `10.0.2.2` alias lets the device hit the host
/// machine — only useful for local dev. Against Render (and any other HTTPS
/// endpoint) the device opens a normal TLS connection, so no special alias
/// is needed. Keep the scheme as `https://` for any non-emulator target.
class Endpoints {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://attendance-api.onrender.com',
  );

  static const String apiPrefix = '/api/v1';

  // Auth
  static String get registerStudent => '/auth/register/student';
  static String get registerTeacher => '/auth/register/teacher';
  static String get login => '/auth/login';
  static String get refresh => '/auth/refresh';
  static String get logout => '/auth/logout';
  static String get me => '/auth/me';

  // Courses
  static String get courses => '/courses';
  static String get myCourses => '/courses/mine';
  static String get myEnrolledCourses => '/courses/enrolled';

  // Sessions
  static String get sessionsActive => '/sessions/active';
  static String get sessionStart => '/sessions/start';
  static String get sessionEnd => '/sessions/end';

  // Attendance
  static String get attendanceMine => '/attendance/mine';
  static String get attendanceCourse => '/attendance/course';
  static String get attendanceRecord => '/attendance/record';

  // Biometrics
  static String get enrollFace => '/biometrics/enroll-face';

  // Attendance verify (Phase 6 — dropped QR + liveness, kept device + geo + face)
  /// POST { sessionId, deviceId, lat, lng, isMockLocation, faceEmbedding }
  /// Phase 6 dropped the QR token + liveness fields.
  static String get verifyAttendance => '/attendance/verify';
}
