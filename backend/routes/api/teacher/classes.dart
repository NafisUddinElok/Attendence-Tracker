import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/teacher/classes
Future<Response> onRequest(RequestContext context) async {
  final user = context.read<Map<String, dynamic>>();
  final teacherId = user['userId'] as String;

  final db = await Database.instance.connection;

  // Auto-expire sessions past their expires_at
  await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE status='ACTIVE' AND expires_at < NOW()",
  );

  final rows = await db.execute(
    r"""SELECT c.id, c.code, c.department, c.academic_session, c.semester,
               c.subject_code, c.subject_name, c.credits, c.status, c.created_at,
               (SELECT COUNT(*) FROM enrollments e WHERE e.class_id = c.id AND e.status='ACTIVE') as student_count,
               (SELECT id FROM class_sessions s WHERE s.class_id = c.id AND s.status='ACTIVE' LIMIT 1) as active_session_id
        FROM classes c
        WHERE (c.teacher_id::text = $1::text OR c.teacher_id = $1::uuid) AND c.status = 'ACTIVE'
        ORDER BY c.created_at DESC""",
    parameters: [teacherId],
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
          'status': r[8],
          'createdAt': r[9]?.toString(),
          'studentCount': r[10],
          'activeSessionId': r[11],
        },
      )
      .toList();

  return Response(
    body: jsonEncode(classes),
    headers: {'Content-Type': 'application/json'},
  );
}
