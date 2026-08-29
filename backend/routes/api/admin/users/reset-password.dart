import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// POST /api/admin/users/reset-password
/// Body: { "identifier": "2023831018" or "teacher@example.com", "newPassword": "..." }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final identifier = (body['identifier'] as String? ?? '').trim();
  final newPassword = body['newPassword'] as String? ?? '';

  if (identifier.isEmpty || newPassword.isEmpty) {
    return _json({'error': 'identifier and newPassword required'}, 400);
  }

  final hash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
  final db = await Database.instance.connection;

  final result = await db.execute(
    r"UPDATE users SET password_hash=$1 WHERE email=$2 OR registration_no=$2 RETURNING id, email, registration_no",
    parameters: [hash, identifier],
  );

  if (result.isEmpty) {
    return _json({'error': 'User not found'}, 404);
  }

  return _json({
    'message': 'Password reset successfully',
    'identifier': identifier,
  });
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
