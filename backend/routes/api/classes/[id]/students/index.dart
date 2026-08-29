import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET  /api/classes/:id/students — list enrolled students
/// POST /api/classes/:id/students — add student by reg no
Future<Response> onRequest(RequestContext context, String id) async {
  final db = await Database.instance.connection;

  if (context.request.method == HttpMethod.get) {
    final rows = await db.execute(
      r"""SELECT u.registration_no, u.department, u.academic_session, e.joined_at, e.status
          FROM enrollments e
          JOIN users u ON u.id = e.student_id
          WHERE e.class_id = $1 AND e.status = 'ACTIVE'
          ORDER BY u.registration_no""",
      parameters: [id],
    );

    final students = rows
        .map(
          (r) => {
            'registrationNo': r[0],
            'department': r[1],
            'academicSession': r[2],
            'joinedAt': r[3]?.toString(),
            'status': r[4],
          },
        )
        .toList();

    return _json(students);
  }

  if (context.request.method == HttpMethod.post) {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final regNo = (body['registrationNo'] as String? ?? '').trim();

    if (regNo.isEmpty) {
      return _json({'error': 'registrationNo required'}, 400);
    }

    final student = await db.execute(
      r"SELECT id FROM users WHERE registration_no=$1 AND role='STUDENT'",
      parameters: [regNo],
    );

    if (student.isEmpty) {
      return _json({'error': 'Student not found'}, 404);
    }

    final studentId = student.first[0] as String;

    try {
      await db.execute(
        r"INSERT INTO enrollments (class_id, student_id) VALUES ($1, $2)",
        parameters: [id, studentId],
      );
      return _json({
        'message': 'Student enrolled',
        'registrationNo': regNo,
      }, HttpStatus.created);
    } catch (e) {
      if (e.toString().contains('unique')) {
        return _json({'error': 'Student already enrolled'}, 409);
      }
      return _json({'error': e.toString()}, 500);
    }
  }

  return Response(statusCode: HttpStatus.methodNotAllowed);
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
