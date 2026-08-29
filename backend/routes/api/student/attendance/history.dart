import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/student/attendance/history
Future<Response> onRequest(RequestContext context) async {
  final user = context.read<Map<String, dynamic>>();
  final studentId = user['userId'] as String;

  final db = await Database.instance.connection;

  final rows = await db.execute(
    r"""SELECT ar.scanned_at, ar.distance_meters, ar.accuracy_meters,
               c.subject_code, c.subject_name, c.department,
               s.started_at as session_date
        FROM attendance_records ar
        JOIN classes c ON c.id = ar.class_id
        JOIN class_sessions s ON s.id = ar.session_id
        WHERE ar.student_id=$1
        ORDER BY ar.scanned_at DESC""",
    parameters: [studentId],
  );

  final history = rows
      .map(
        (r) => {
          'scannedAt': r[0]?.toString(),
          'distanceMeters': r[1],
          'accuracyMeters': r[2],
          'subjectCode': r[3],
          'subjectName': r[4],
          'department': r[5],
          'sessionDate': r[6]?.toString(),
        },
      )
      .toList();

  return Response(
    body: jsonEncode(history),
    headers: {'Content-Type': 'application/json'},
  );
}
