class ApiConfig {
  // Android emulator: use 10.0.2.2 to reach your host machine's localhost.
  // Physical device: use your computer's LAN IP, e.g. http://192.168.0.105:5000
  // iOS simulator: http://localhost:5000 works fine.
  static const String baseUrl = "http://192.168.0.185:5000";

  // Auth
  static const String login = "$baseUrl/auth/login";
  static const String register = "$baseUrl/auth/register";

  // Admin
  static const String adminTeachers = "$baseUrl/admin/teachers";
  static const String adminStudents = "$baseUrl/admin/students";
  static const String adminCourses = "$baseUrl/admin/courses";
  static const String adminEnroll = "$baseUrl/admin/enroll";
  static const String adminNotifications = "$baseUrl/admin/notifications";
  static String adminResolveNotification(int id) =>
      "$baseUrl/admin/notifications/$id/resolve";
  static String adminAssignTeacher(int courseId) =>
      "$baseUrl/admin/courses/$courseId/assign-teacher";
  static String adminCourseEnrollments(int courseId) =>
      "$baseUrl/admin/courses/$courseId/enrollments";

  // Teacher
  static const String teacherCourses = "$baseUrl/teacher/courses";
  static const String teacherSessionStart = "$baseUrl/teacher/session/start";
  static String teacherSessionEnd(int sessionId) =>
      "$baseUrl/teacher/session/$sessionId/end";
  static String teacherSessionCsv(int sessionId) =>
      "$baseUrl/teacher/session/$sessionId/attendance-csv";
  static String teacherCourseSummaryCsv(int courseId) =>
      "$baseUrl/teacher/course/$courseId/summary-csv";
  static const String teacherDropCourseRequest =
      "$baseUrl/teacher/drop-course-request";

  // Student
  static const String studentCourses = "$baseUrl/student/courses";
  static String studentActiveSession(int courseId) =>
      "$baseUrl/student/session/active/$courseId";
  static const String studentMarkAttendance =
      "$baseUrl/student/attendance/mark";
}
