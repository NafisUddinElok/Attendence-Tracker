import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/admin/teachers?department=...
/// POST /api/admin/teachers
Future<Response> onRequest(RequestContext context) async {
  final db = await Database.instance.connection;

  if (context.request.method == HttpMethod.get) {
    final dept = context.request.uri.queryParameters['department'];
    final rows = dept != null
        ? await db.execute(
            r"SELECT id, email, department FROM users WHERE role='TEACHER' AND department=$1 ORDER BY email",
            parameters: [dept],
          )
        : await db.execute(
            "SELECT id, email, department FROM users WHERE role='TEACHER' ORDER BY email",
          );

    final teachers = rows
        .map((r) => {'id': r[0], 'email': r[1], 'department': r[2]})
        .toList();
    return _json(teachers);
  }

  if (context.request.method == HttpMethod.post) {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final email = (body['email'] as String? ?? '').trim();
    final password = (body['password'] as String? ?? '').trim();
    final department = (body['department'] as String? ?? '').trim();

    if (email.isEmpty || password.isEmpty || department.isEmpty) {
      return _json({
        'error': 'Email, password, and department are required',
      }, 400);
    }

    final hash = BCrypt.hashpw(password, BCrypt.gensalt());

    try {
      final result = await db.execute(
        r"""INSERT INTO users (role, email, password_hash, department)
            VALUES ('TEACHER', $1, $2, $3)
            ON CONFLICT (email) DO UPDATE
            SET password_hash = EXCLUDED.password_hash,
                department = EXCLUDED.department
            RETURNING id, (xmax = 0) AS is_new""",
        parameters: [email, hash, department],
      );

      final teacherId = result.first[0] as String;
      final isNew = result.first[1] as bool? ?? true;

      return _json({
        'id': teacherId,
        'email': email,
        'department': department,
        'isNew': isNew,
        'message': isNew
            ? 'Teacher created successfully'
            : 'Teacher already existed — password and department updated.',
      }, isNew ? HttpStatus.created : HttpStatus.ok);
    } catch (e) {
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
