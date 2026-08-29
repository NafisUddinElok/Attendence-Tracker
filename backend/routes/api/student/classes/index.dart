import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/student/classes — auto-enrolled active classes
Future<Response> onRequest(RequestContext context) async {
  final user = context.read<Map<String, dynamic>>();
  final studentId = user['userId'] as String;

  final db = await Database.instance.connection;

  // Auto-expire sessions
  await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE status='ACTIVE' AND expires_at < NOW()",
  );

  final rows = await db.execute(
    r"""SELECT c.id, c.code, c.department, c.academic_session, c.semester,
               c.subject_code, c.subject_name, c.credits,
               u.email as teacher_email,
               (SELECT id FROM class_sessions s WHERE s.class_id=c.id AND s.status='ACTIVE' LIMIT 1) as active_session_id
        FROM enrollments e
        JOIN classes c ON c.id = e.class_id
        JOIN users u ON u.id = c.teacher_id
        WHERE e.student_id=$1 AND e.status='ACTIVE' AND c.status='ACTIVE'
        ORDER BY c.subject_code""",
    parameters: [studentId],
  );

  final classes = rows
      .map(
        (r) => {
          'id': r[0],
          'code': r[1],
          'department': r[2],
          'academicSession': r[3],
          'semester': r[4],
          'subjectCode': r[5],
          'subjectName': r[6],
          'credits': r[7],
          'teacherEmail': r[8],
          'activeSessionId': r[9],
        },
      )
      .toList();

  return Response(
    body: jsonEncode(classes),
    headers: {'Content-Type': 'application/json'},
  );
}
