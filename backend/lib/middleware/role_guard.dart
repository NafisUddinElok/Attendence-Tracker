import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Returns a middleware that only allows requests from users with [requiredRole].
/// Must be used AFTER [authMiddleware].
Middleware roleGuard(String requiredRole) {
  return (handler) {
    return (context) async {
      final user = context.read<Map<String, dynamic>>();
      final role = user['role'] as String?;
      if (role != requiredRole) {
        return Response(
          statusCode: HttpStatus.forbidden,
          body: jsonEncode({
            'error': 'Access denied. Required role: $requiredRole',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return handler(context);
    };
  };
}
