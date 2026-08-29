import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// POST /api/sessions/start
/// Body: { "classId", "latitude", "longitude", "radiusMeters", "durationSeconds" }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final classId = body['classId'] as String? ?? '';
  final latitude = (body['latitude'] as num?)?.toDouble();
  final longitude = (body['longitude'] as num?)?.toDouble();
  final radius = (body['radiusMeters'] as num?)?.toDouble() ?? 30.0;
  final duration = (body['durationSeconds'] as num?)?.toInt() ?? 60;

  if (classId.isEmpty || latitude == null || longitude == null) {
    return _json({'error': 'classId, latitude, longitude required'}, 400);
  }

  final db = await Database.instance.connection;

  // End any existing active session for this class first
  await db.execute(
    r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE class_id=$1 AND status='ACTIVE'",
    parameters: [classId],
  );

  final result = await db.execute(
    r"""INSERT INTO class_sessions (class_id, latitude, longitude, radius_meters, expires_at)
        VALUES ($1, $2, $3, $4, NOW() + ($5 || ' seconds')::interval)
        RETURNING id, started_at, expires_at""",
    parameters: [classId, latitude, longitude, radius, duration.toString()],
  );

  final row = result.first;

  return _json({
    'id': row[0],
    'classId': classId,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radius,
    'durationSeconds': duration,
    'startedAt': row[1]?.toString(),
    'expiresAt': row[2]?.toString(),
    'status': 'ACTIVE',
  }, HttpStatus.created);
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
