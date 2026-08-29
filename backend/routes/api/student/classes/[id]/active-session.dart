import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/student/classes/:id/active-session
/// Returns:
/// 1. Course Details & Teacher info
/// 2. Course Attendance Summary (Total classes held, Total present, Attendance %)
/// 3. Session-by-session breakdown (Present/Absent for each class)
/// 4. Active Live Session info (if one is currently open)
Future<Response> onRequest(RequestContext context, String id) async {
  final user = context.read<Map<String, dynamic>>();
  final studentId = user['userId'] as String;

  final db = await Database.instance.connection;

  // Auto-expire sessions
  await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE status='ACTIVE' AND expires_at < NOW()",
  );

  // 1. Course Info
  final courseRows = await db.execute(
    r"""SELECT c.id, c.code, c.department, c.academic_session, c.semester,
               c.subject_code, c.subject_name, u.email as teacher_email
        FROM classes c
        LEFT JOIN users u ON u.id = c.teacher_id
        WHERE c.id = $1""",
    parameters: [id],
  );

  final courseInfo = courseRows.isNotEmpty
      ? {
          'id': courseRows.first[0],
          'code': courseRows.first[1],
          'department': courseRows.first[2],
          'academicSession': courseRows.first[3],
          'semester': courseRows.first[4],
          'subjectCode': courseRows.first[5],
          'subjectName': courseRows.first[6],
          'teacherEmail': courseRows.first[7],
        }
      : null;

  // 2. Active Session Info
  final sessions = await db.execute(
    r"""SELECT s.id, s.latitude, s.longitude, s.radius_meters, s.expires_at, s.started_at
        FROM class_sessions s
        WHERE s.class_id=$1 AND s.status='ACTIVE'
        LIMIT 1""",
    parameters: [id],
  );

  bool hasActive = sessions.isNotEmpty;
  String? activeSessionId;
  dynamic activeLat, activeLon, activeRadius, activeExpires, activeStarted;
  bool alreadyClaimed = false;

  if (hasActive) {
    final s = sessions.first;
    activeSessionId = s[0] as String;
    activeLat = s[1];
    activeLon = s[2];
    activeRadius = s[3];
    activeExpires = s[4]?.toString();
    activeStarted = s[5]?.toString();

    final claimed = await db.execute(
      r"SELECT id FROM attendance_records WHERE session_id=$1 AND student_id=$2",
      parameters: [activeSessionId, studentId],
    );
    alreadyClaimed = claimed.isNotEmpty;
  }

  // 3. Total Sessions & Attendance Count for this Course
  final totalSessionsRes = await db.execute(
    r"SELECT COUNT(*) FROM class_sessions WHERE class_id=$1",
    parameters: [id],
  );
  final totalSessionsCount = (totalSessionsRes.first[0] as num?)?.toInt() ?? 0;

  final presentRes = await db.execute(
    r"SELECT COUNT(*) FROM attendance_records WHERE class_id=$1 AND student_id=$2",
    parameters: [id, studentId],
  );
  final presentCount = (presentRes.first[0] as num?)?.toInt() ?? 0;

  final percentage = totalSessionsCount > 0
      ? (presentCount / totalSessionsCount) * 100
      : 100.0;

  // 4. Session-by-Session Breakdown List
  final historyRows = await db.execute(
    r"""SELECT s.id, s.started_at, s.expires_at, s.status as session_status,
               a.id as attendance_id, a.scanned_at, a.distance_meters
        FROM class_sessions s
        LEFT JOIN attendance_records a ON a.session_id = s.id AND a.student_id = $2
        WHERE s.class_id = $1
        ORDER BY s.started_at DESC""",
    parameters: [id, studentId],
  );

  final sessionHistory = historyRows
      .map(
        (r) => {
          'sessionId': r[0],
          'startedAt': r[1]?.toString(),
          'expiresAt': r[2]?.toString(),
          'sessionStatus': r[3],
          'isPresent': r[4] != null,
          'scannedAt': r[5]?.toString(),
          'distanceMeters': r[6],
        },
      )
      .toList();

  return Response(
    body: jsonEncode({
      'active': hasActive,
      if (hasActive) ...{
        'sessionId': activeSessionId,
        'latitude': activeLat,
        'longitude': activeLon,
        'radiusMeters': activeRadius,
        'expiresAt': activeExpires,
        'startedAt': activeStarted,
        'alreadyClaimed': alreadyClaimed,
      },
      'course': courseInfo,
      'stats': {
        'totalSessions': totalSessionsCount,
        'presentCount': presentCount,
        'absentCount': (totalSessionsCount - presentCount).clamp(0, 9999),
        'percentage': percentage,
      },
      'history': sessionHistory,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
