import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/sessions/:id/records — live check-ins for a session
Future<Response> onRequest(RequestContext context, String id) async {
  final db = await Database.instance.connection;

  final session = await db.execute(
    r"SELECT id, status, expires_at, radius_meters, latitude, longitude FROM class_sessions WHERE id=$1",
    parameters: [id],
  );

  if (session.isEmpty) {
    return Response(
      statusCode: 404,
      body: jsonEncode({'error': 'Session not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final s = session.first;

  final records = await db.execute(
    r"""SELECT ar.registration_no, ar.distance_meters, ar.accuracy_meters, ar.scanned_at
        FROM attendance_records ar
        WHERE ar.session_id = $1
        ORDER BY ar.scanned_at DESC""",
    parameters: [id],
  );

  return Response(
    body: jsonEncode({
      'sessionId': id,
      'status': s[1],
      'expiresAt': s[2]?.toString(),
      'radiusMeters': s[3],
      'latitude': s[4],
      'longitude': s[5],
      'checkIns': records
          .map(
            (r) => {
              'registrationNo': r[0],
              'distanceMeters': r[1],
              'accuracyMeters': r[2],
              'scannedAt': r[3]?.toString(),
            },
          )
          .toList(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
