class CourseModel {
  final int id;
  final String courseName;
  final String courseCode;
  final String? teacherName;

  CourseModel({
    required this.id,
    required this.courseName,
    required this.courseCode,
    this.teacherName,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    // handles both admin's "GET /admin/courses" shape and plain course object
    String? teacherName;
    if (json['teacher'] != null) {
      teacherName = json['teacher']['name'];
    } else if (json['Course'] != null && json['Course']['teacher'] != null) {
      teacherName = json['Course']['teacher']['name'];
    }

    // student endpoint nests course inside "Course"
    final courseData = json['Course'] ?? json;

    return CourseModel(
      id: courseData['id'],
      courseName: courseData['course_name'] ?? '',
      courseCode: courseData['course_code'] ?? '',
      teacherName: teacherName,
    );
  }
}
