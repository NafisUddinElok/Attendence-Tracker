/// Represents the authenticated user from JWT login response.
class AuthUser {
  final String token;
  final String role;
  final String userId;
  final String? email;
  final String? registrationNo;
  final String? department;
  final String? academicSession;

  const AuthUser({
    required this.token,
    required this.role,
    required this.userId,
    this.email,
    this.registrationNo,
    this.department,
    this.academicSession,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        token: json['token'] as String,
        role: json['role'] as String,
        userId: json['userId'] as String,
        email: json['email'] as String?,
        registrationNo: json['registrationNo'] as String?,
        department: json['department'] as String?,
        academicSession: json['academicSession'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role,
        'userId': userId,
        if (email != null) 'email': email,
        if (registrationNo != null) 'registrationNo': registrationNo,
        if (department != null) 'department': department,
        if (academicSession != null) 'academicSession': academicSession,
      };

  String get displayName => email ?? registrationNo ?? 'User';
}

/// Represents a class/course.
class ClassModel {
  final String id;
  final String code;
  final String department;
  final String academicSession;
  final String? semester;
  final String subjectCode;
  final String? subjectName;
  final double? credits;
  final String status;
  final String? createdAt;
  final String? teacherEmail;
  final String? teacherId;
  final int? studentCount;
  final String? activeSessionId;

  const ClassModel({
    required this.id,
    required this.code,
    required this.department,
    required this.academicSession,
    this.semester,
    required this.subjectCode,
    this.subjectName,
    this.credits,
    required this.status,
    this.createdAt,
    this.teacherEmail,
    this.teacherId,
    this.studentCount,
    this.activeSessionId,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) => ClassModel(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        academicSession: json['academicSession']?.toString() ?? '',
        semester: json['semester']?.toString(),
        subjectCode: json['subjectCode']?.toString() ?? '',
        subjectName: json['subjectName']?.toString(),
        credits: json['credits'] != null
            ? double.tryParse(json['credits'].toString())
            : null,
        status: json['status']?.toString() ?? 'ACTIVE',
        createdAt: json['createdAt']?.toString(),
        teacherEmail: json['teacherEmail']?.toString(),
        teacherId: json['teacherId']?.toString(),
        studentCount: json['studentCount'] != null
            ? int.tryParse(json['studentCount'].toString())
            : null,
        activeSessionId: json['activeSessionId']?.toString(),
      );

  bool get hasActiveSession => activeSessionId != null;
}

/// Represents an attendance session.
class SessionModel {
  final String id;
  final String classId;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? expiresAt;
  final String? startedAt;
  final String status;
  final bool alreadyClaimed;
  final List<CheckInRecord> checkIns;

  const SessionModel({
    required this.id,
    required this.classId,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.expiresAt,
    this.startedAt,
    required this.status,
    this.alreadyClaimed = false,
    this.checkIns = const [],
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        id: json['sessionId']?.toString() ?? '',
        classId: json['classId']?.toString() ?? '',
        latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
        longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
        radiusMeters:
            double.tryParse(json['radiusMeters']?.toString() ?? '30') ?? 30.0,
        expiresAt: json['expiresAt'] as String?,
        startedAt: json['startedAt'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        alreadyClaimed: json['alreadyClaimed'] as bool? ?? false,
      );
}

/// Represents a student check-in record.
class CheckInRecord {
  final String registrationNo;
  final double? distanceMeters;
  final double? accuracyMeters;
  final String? scannedAt;

  const CheckInRecord({
    required this.registrationNo,
    this.distanceMeters,
    this.accuracyMeters,
    this.scannedAt,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) => CheckInRecord(
        registrationNo: json['registrationNo']?.toString() ?? '',
        distanceMeters: json['distanceMeters'] != null
            ? double.tryParse(json['distanceMeters'].toString())
            : null,
        accuracyMeters: json['accuracyMeters'] != null
            ? double.tryParse(json['accuracyMeters'].toString())
            : null,
        scannedAt: json['scannedAt'] as String?,
      );
}

/// Represents attendance matrix data.
class AttendanceMatrix {
  final String classId;
  final String subjectCode;
  final String? subjectName;
  final int totalSessions;
  final int totalStudents;
  final double averageAttendancePct;
  final List<Map<String, dynamic>> sessions;
  final List<int> columnTotals;
  final List<MatrixRow> rows;

  const AttendanceMatrix({
    required this.classId,
    required this.subjectCode,
    this.subjectName,
    required this.totalSessions,
    required this.totalStudents,
    required this.averageAttendancePct,
    required this.sessions,
    required this.columnTotals,
    required this.rows,
  });

  factory AttendanceMatrix.fromJson(Map<String, dynamic> json) =>
      AttendanceMatrix(
        classId: json['classId']?.toString() ?? '',
        subjectCode: json['subjectCode']?.toString() ?? '',
        subjectName: json['subjectName'] as String?,
        totalSessions:
            int.tryParse(json['totalSessions']?.toString() ?? '0') ?? 0,
        totalStudents:
            int.tryParse(json['totalStudents']?.toString() ?? '0') ?? 0,
        averageAttendancePct:
            double.tryParse(json['averageAttendancePct']?.toString() ?? '0') ??
                0.0,
        sessions: List<Map<String, dynamic>>.from(
          json['sessions'] as List<dynamic>? ?? [],
        ),
        columnTotals: (json['columnTotals'] as List<dynamic>? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toList(),
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((r) => MatrixRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class MatrixRow {
  final String registrationNo;
  final List<String> cells; // 'P' or 'A'
  final int totalPresent;
  final int totalSessions;
  final double percentage;

  const MatrixRow({
    required this.registrationNo,
    required this.cells,
    required this.totalPresent,
    required this.totalSessions,
    required this.percentage,
  });

  factory MatrixRow.fromJson(Map<String, dynamic> json) => MatrixRow(
        registrationNo: json['registrationNo']?.toString() ?? '',
        cells: List<String>.from(json['cells'] as List<dynamic>? ?? []),
        totalPresent:
            int.tryParse(json['totalPresent']?.toString() ?? '0') ?? 0,
        totalSessions:
            int.tryParse(json['totalSessions']?.toString() ?? '0') ?? 0,
        percentage:
            double.tryParse(json['percentage']?.toString() ?? '0') ?? 0.0,
      );
}

/// Attendance history item.
class AttendanceHistory {
  final String? scannedAt;
  final double? distanceMeters;
  final double? accuracyMeters;
  final String subjectCode;
  final String? subjectName;
  final String? department;
  final String? sessionDate;

  const AttendanceHistory({
    this.scannedAt,
    this.distanceMeters,
    this.accuracyMeters,
    required this.subjectCode,
    this.subjectName,
    this.department,
    this.sessionDate,
  });

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) =>
      AttendanceHistory(
        scannedAt: json['scannedAt'] as String?,
        distanceMeters: json['distanceMeters'] != null
            ? double.tryParse(json['distanceMeters'].toString())
            : null,
        accuracyMeters: json['accuracyMeters'] != null
            ? double.tryParse(json['accuracyMeters'].toString())
            : null,
        subjectCode: json['subjectCode']?.toString() ?? '',
        subjectName: json['subjectName'] as String?,
        department: json['department'] as String?,
        sessionDate: json['sessionDate'] as String?,
      );
}

/// Enrolled student info.
class EnrolledStudent {
  final String registrationNo;
  final String? department;
  final String? academicSession;
  final String? joinedAt;
  final String status;

  const EnrolledStudent({
    required this.registrationNo,
    this.department,
    this.academicSession,
    this.joinedAt,
    required this.status,
  });

  factory EnrolledStudent.fromJson(Map<String, dynamic> json) =>
      EnrolledStudent(
        registrationNo: json['registrationNo']?.toString() ?? '',
        department: json['department'] as String?,
        academicSession: json['academicSession'] as String?,
        joinedAt: json['joinedAt'] as String?,
        status: json['status']?.toString() ?? 'ACTIVE',
      );
}
