import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';

String _secret() {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  return env['JWT_SECRET'] ??
      Platform.environment['JWT_SECRET'] ??
      'fallback_secret_key_change_me';
}

/// Generates a signed JWT containing userId, role, email, registrationNo.
String generateToken({
  required String userId,
  required String role,
  String? email,
  String? registrationNo,
}) {
  final jwt = JWT(
    {
      'userId': userId,
      'role': role,
      if (email != null) 'email': email,
      if (registrationNo != null) 'registrationNo': registrationNo,
    },
    issuer: 'att-system',
  );
  return jwt.sign(
    SecretKey(_secret()),
    expiresIn: const Duration(days: 7),
  );
}

/// Verifies a JWT and returns its payload map.
/// Throws [JWTException] if invalid.
Map<String, dynamic> verifyToken(String token) {
  final jwt = JWT.verify(token, SecretKey(_secret()));
  return jwt.payload as Map<String, dynamic>;
}
