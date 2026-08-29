import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response(
    body: jsonEncode({
      'service': 'GPS Attendance System API',
      'version': '1.0.0',
      'status': 'running',
      'endpoints': {
        'auth': 'POST /api/auth/login',
        'admin': '/api/admin/*',
        'teacher': '/api/teacher/*',
        'sessions': '/api/sessions/*',
        'classes': '/api/classes/*',
        'student': '/api/student/*',
        'attendance': '/api/attendance/claim',
      },
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
