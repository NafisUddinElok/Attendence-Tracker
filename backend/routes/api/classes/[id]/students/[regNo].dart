import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// DELETE /api/classes/:id/students/:regNo
/// Removes student from class and deletes their attendance records for this class.
Future<Response> onRequest(
  RequestContext context,
  String id,
  String regNo,
) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final db = await Database.instance.connection;

  final student = await db.execute(
    r"SELECT id FROM users WHERE registration_no=$1",
    parameters: [regNo],
  );

  if (student.isEmpty) {
    return Response(
      statusCode: 404,
      body: jsonEncode({'error': 'Student not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final studentId = student.first[0] as String;

  // Delete attendance records first
  await db.execute(
    r"DELETE FROM attendance_records WHERE class_id=$1 AND student_id=$2",
    parameters: [id, studentId],
  );

  // Remove enrollment
  await db.execute(
    r"DELETE FROM enrollments WHERE class_id=$1 AND student_id=$2",
    parameters: [id, studentId],
  );

  return Response(
    body: jsonEncode({
      'message': 'Student removed and attendance records deleted',
      'registrationNo': regNo,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
