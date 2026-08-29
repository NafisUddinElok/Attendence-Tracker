import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// POST /api/sessions/manual
/// Body: { "classId": "...", "records": [ { "studentId": "...", "registrationNo": "...", "status": "P" } ] }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<Map<String, dynamic>>();
  final role = user['role'] as String?;

  if (role != 'TEACHER' && role != 'ADMIN') {
    return _json({
      'error': 'Only teachers can record manual attendance',
    }, HttpStatus.forbidden);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final classId = body['classId'] as String? ?? '';
  final records = (body['records'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .toList();

  if (classId.isEmpty || records.isEmpty) {
    return _json({'error': 'classId and records are required'}, 400);
  }

  final db = await Database.instance.connection;

  // 1. Create a completed session record for this manual attendance
  final sessionRes = await db.execute(
    r"""INSERT INTO class_sessions (class_id, latitude, longitude, radius_meters, status, started_at, ended_at, expires_at)
        VALUES ($1, 0, 0, 0, 'ENDED', NOW(), NOW(), NOW())
        RETURNING id""",
    parameters: [classId],
  );

  final sessionId = sessionRes.first[0] as String;
  int presentCount = 0;

  // 2. Insert attendance records for all students marked 'P'
  for (final rec in records) {
    final studentId = rec['studentId'] as String? ?? '';
    final regNo = rec['registrationNo'] as String? ?? '';
    final status = (rec['status'] as String? ?? 'A').toUpperCase();

    if (status == 'P' && regNo.isNotEmpty) {
      // Find student ID if not provided
      String resolvedStudentId = studentId;
      if (resolvedStudentId.isEmpty) {
        final u = await db.execute(
          r'SELECT id FROM users WHERE registration_no = $1',
          parameters: [regNo],
        );
        if (u.isNotEmpty) {
          resolvedStudentId = u.first[0] as String;
        }
      }

      if (resolvedStudentId.isNotEmpty) {
        await db.execute(
          r"""INSERT INTO attendance_records
              (session_id, class_id, student_id, registration_no, latitude, longitude, distance_meters, accuracy_meters, device_install_id)
              VALUES ($1, $2, $3, $4, 0, 0, 0, 0, 'MANUAL_TEACHER')
              ON CONFLICT DO NOTHING""",
          parameters: [sessionId, classId, resolvedStudentId, regNo],
        );
        presentCount++;
      }
    }
  }

  return _json({
    'sessionId': sessionId,
    'classId': classId,
    'totalStudents': records.length,
    'presentCount': presentCount,
    'absentCount': records.length - presentCount,
    'message':
        'Manual attendance recorded successfully! Present: $presentCount / ${records.length}',
  }, HttpStatus.created);
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
