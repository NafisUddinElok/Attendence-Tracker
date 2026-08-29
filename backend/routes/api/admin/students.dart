import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';
import 'package:attendance_backend/utils/reg_parser.dart';

/// POST /api/admin/students
/// Body: { "registrationNo": "2023831018", "password": "..." }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final regNo = (body['registrationNo'] as String? ?? '').trim();
  final password = (body['password'] as String? ?? '').trim();

  if (regNo.isEmpty || password.isEmpty) {
    return _json({
      'error': 'Registration number and password are required',
    }, 400);
  }

  final session = parseSession(regNo);
  final department = parseDepartment(regNo);
  final hash = BCrypt.hashpw(password, BCrypt.gensalt());

  final db = await Database.instance.connection;

  try {
    // Insert or update existing student on conflict
    final result = await db.execute(
      r"""INSERT INTO users (role, registration_no, password_hash, department, academic_session)
          VALUES ('STUDENT', $1, $2, $3, $4)
          ON CONFLICT (registration_no) DO UPDATE
          SET password_hash = EXCLUDED.password_hash,
              department = EXCLUDED.department,
              academic_session = EXCLUDED.academic_session
          RETURNING id, (xmax = 0) AS is_new""",
      parameters: [regNo, hash, department, session],
    );

    final studentId = result.first[0] as String;
    final isNew = result.first[1] as bool? ?? true;

    // Auto-enroll into matching active classes
    final enrolled = await db.execute(
      r"""INSERT INTO enrollments (class_id, student_id)
          SELECT id, $1 FROM classes
          WHERE department = $2 AND academic_session = $3 AND status = 'ACTIVE'
          ON CONFLICT DO NOTHING""",
      parameters: [studentId, department, session],
    );

    return _json({
      'id': studentId,
      'registrationNo': regNo,
      'department': department,
      'academicSession': session,
      'isNew': isNew,
      'enrolledCount': enrolled.affectedRows,
      'message': isNew
          ? 'Student created and auto-enrolled successfully.'
          : 'Student already existed — password updated and enrolled in matching classes.',
    }, isNew ? HttpStatus.created : HttpStatus.ok);
  } catch (e) {
    return _json({'error': e.toString()}, 500);
  }
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
