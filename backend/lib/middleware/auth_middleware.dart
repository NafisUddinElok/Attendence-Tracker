import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:attendance_backend/utils/jwt_helper.dart';

/// Middleware that validates Bearer JWT and optionally checks the role.
Middleware authGuard([String? requiredRole]) {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: jsonEncode({
            'error': 'Missing or invalid Authorization header',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring(7);
      try {
        final payload = verifyToken(token);
        final userRole = payload['role'] as String?;

        if (requiredRole != null && userRole != requiredRole) {
          return Response(
            statusCode: HttpStatus.forbidden,
            body: jsonEncode({
              'error': 'Access denied. Required role: $requiredRole',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final newContext = context.provide<Map<String, dynamic>>(() => payload);
        return await handler(newContext);
      } on JWTExpiredException {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: jsonEncode({'error': 'Token expired'}),
          headers: {'Content-Type': 'application/json'},
        );
      } on JWTException catch (e) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: jsonEncode({'error': 'Invalid token: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

Middleware authMiddleware() => authGuard();
