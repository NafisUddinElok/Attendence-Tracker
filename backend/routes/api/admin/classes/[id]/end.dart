import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// POST /api/admin/classes/:id/end
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final db = await Database.instance.connection;

  final result = await db.execute(
    r"UPDATE classes SET status='ENDED' WHERE id=$1 AND status='ACTIVE' RETURNING id",
    parameters: [id],
  );

  if (result.isEmpty) {
    return _json({'error': 'Class not found or already ended'}, 404);
  }

  // Also end any active sessions for this class
  await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE class_id=$1 AND status='ACTIVE'",
    parameters: [id],
  );

  return _json({'message': 'Class ended successfully', 'classId': id});
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
