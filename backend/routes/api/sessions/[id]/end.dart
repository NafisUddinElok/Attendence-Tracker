import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// POST /api/sessions/:id/end
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final db = await Database.instance.connection;
  final result = await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE id=$1 AND status='ACTIVE' RETURNING id",
    parameters: [id],
  );

  if (result.isEmpty) {
    return Response(
      statusCode: 404,
      body: jsonEncode({'error': 'Session not found or already ended'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  return Response(
    body: jsonEncode({'message': 'Session ended', 'sessionId': id}),
    headers: {'Content-Type': 'application/json'},
  );
}
