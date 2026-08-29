import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';
import 'package:attendance_backend/utils/haversine.dart';

/// POST /api/attendance/claim
/// Body: { "sessionId", "latitude", "longitude", "accuracyMeters", "deviceInstallId" }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<Map<String, dynamic>>();
  final studentId = user['userId'] as String;
  final regNo = user['registrationNo'] as String? ?? '';

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final sessionId = body['sessionId'] as String? ?? '';
  final lat = (body['latitude'] as num?)?.toDouble();
  final lon = (body['longitude'] as num?)?.toDouble();
  final accuracy = (body['accuracyMeters'] as num?)?.toDouble() ?? 0.0;
  final deviceId = body['deviceInstallId'] as String? ?? 'unknown';

  if (sessionId.isEmpty || lat == null || lon == null) {
    return _json({'error': 'sessionId, latitude, longitude required'}, 400);
  }

  final db = await Database.instance.connection;

  // Get session details
  final sessions = await db.execute(
    r"""SELECT id, class_id, latitude, longitude, radius_meters, status, expires_at
        FROM class_sessions WHERE id=$1""",
    parameters: [sessionId],
  );

  if (sessions.isEmpty) {
    return _json({'error': 'Session not found'}, 404);
  }

  final s = sessions.first;
  final status = s[5] as String;
  final expiresAt = s[6] as DateTime?;

  if (status != 'ACTIVE' ||
      (expiresAt != null && expiresAt.isBefore(DateTime.now()))) {
    // Auto-expire
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      await db.execute(
        r"UPDATE class_sessions SET status='ENDED', ended_at=NOW() WHERE id=$1",
        parameters: [sessionId],
      );
    }
    return _json({'error': 'Session is not active or has expired'}, 410);
  }

  final classId = s[1] as String;
  final sessLat = (s[2] as num).toDouble();
  final sessLon = (s[3] as num).toDouble();
  final radius = (s[4] as num).toDouble();

  // Haversine distance check
  final distance = haversineDistance(lat, lon, sessLat, sessLon);

  // If radius is not unlimited (e.g. test mode >= 50000m) and distance exceeds radius
  if (radius < 50000 && distance > radius) {
    final distStr = distance > 1000
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : '${distance.round()} m';
    return _json({
      'error':
          'Outside geofence: You are $distStr away from classroom (Allowed: ${radius.round()}m)',
      'distanceMeters': distance.round(),
      'allowedRadius': radius,
    }, 403);
  }

  // Record attendance (UNIQUE constraint prevents duplicates)
  try {
    await db.execute(
      r"""INSERT INTO attendance_records
          (session_id, class_id, student_id, registration_no, latitude, longitude, distance_meters, accuracy_meters, device_install_id)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)""",
      parameters: [
        sessionId,
        classId,
        studentId,
        regNo,
        lat,
        lon,
        distance,
        accuracy,
        deviceId,
      ],
    );

    return _json({
      'message': 'Attendance marked successfully!',
      'distanceMeters': distance.round(),
      'status': 'PRESENT',
    });
  } catch (e) {
    if (e.toString().contains('unique')) {
      return _json({
        'error': 'Attendance already claimed for this session',
      }, 409);
    }
    return _json({'error': e.toString()}, 500);
  }
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
