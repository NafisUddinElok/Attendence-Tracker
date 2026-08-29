import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';
import 'package:attendance_backend/utils/jwt_helper.dart';

/// POST /api/auth/login
/// Body: { "emailOrReg": "...", "password": "..." }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final identifier = body['emailOrReg'] as String? ?? '';
  final password = body['password'] as String? ?? '';

  if (identifier.isEmpty || password.isEmpty) {
    return _json({'error': 'emailOrReg and password are required'}, 400);
  }

  final db = await Database.instance.connection;

  final result = await db.execute(
    r"""SELECT id, role, email, registration_no, password_hash, department, academic_session
        FROM users
        WHERE email = $1 OR registration_no = $1
        LIMIT 1""",
    parameters: [identifier],
  );

  if (result.isEmpty) {
    return _json({'error': 'Invalid credentials'}, HttpStatus.unauthorized);
  }

  final row = result.first;
  final hash = row[4] as String;

  if (!BCrypt.checkpw(password, hash)) {
    return _json({'error': 'Invalid credentials'}, HttpStatus.unauthorized);
  }

  final userId = row[0] as String;
  final role = row[1] as String;
  final email = row[2] as String?;
  final regNo = row[3] as String?;

  final token = generateToken(
    userId: userId,
    role: role,
    email: email,
    registrationNo: regNo,
  );

  return _json({
    'token': token,
    'role': role,
    'userId': userId,
    if (email != null) 'email': email,
    if (regNo != null) 'registrationNo': regNo,
    'department': row[5],
    'academicSession': row[6],
  });
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
