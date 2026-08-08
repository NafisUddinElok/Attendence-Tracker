// lib/attendance_service.dart
//
// Flutter client for the geofencing attendance backend.
//
// Dependencies (add to pubspec.yaml):
//   http: ^1.2.0
//   geolocator: ^13.0.0
//   flutter_secure_storage: ^9.2.0
//
// Android setup (android/app/src/main/AndroidManifest.xml):
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//
// iOS setup (ios/Runner/Info.plist):
//   <key>NSLocationWhenInUseUsageDescription</key>
//   <string>We use your location to verify classroom attendance.</string>

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AttendanceService {
  // Point this at your deployed server. For local testing on a physical
  // device, "localhost" won't work — use your machine's LAN IP instead
  // (e.g. http://192.168.1.10:3000). Android emulator uses 10.0.2.2.
  static const String baseUrl = 'http://192.168.0.140:3000';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  /// Logs in and stores the JWT securely (Keychain on iOS, Keystore on Android).
  static Future<bool> login(String studentCode, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'studentCode': studentCode, 'password': password}),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true || data['token'] == null) {
      return false;
    }

    await _storage.write(key: _tokenKey, value: data['token'] as String);
    return true;
  }

  static Future<String?> _getToken() => _storage.read(key: _tokenKey);

  static Future<void> logout() => _storage.delete(key: _tokenKey);

  /// Result of an attendance attempt, surfaced to the UI.
  /// [faceVerified] must come from a completed FaceLivenessScreen check —
  /// the backend rejects the request outright if this isn't true.
  static Future<AttendanceResult> markAttendance(int sessionId, {required bool faceVerified}) async {
    final token = await _getToken();
    if (token == null) {
      return AttendanceResult(success: false, message: 'Please log in again.');
    }

    if (!faceVerified) {
      return AttendanceResult(success: false, message: 'Face verification is required.');
    }

    // 1. Make sure location services + permission are actually available.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AttendanceResult(success: false, message: 'Please enable location services.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return AttendanceResult(success: false, message: 'Location permission is required.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return AttendanceResult(
        success: false,
        message: 'Location permission permanently denied. Enable it from Settings.',
      );
    }

    // 2. Get current position. On Android, Position.isMocked reflects the OS's
    // real mock-location-provider check — this is what we forward to the
    // server. On iOS, isMocked is always false (no reliable native signal);
    // treat that as a known platform limitation, not a guarantee.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 3. Call the backend.
    final response = await http.post(
      Uri.parse('$baseUrl/geofencing/mark-attendance'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'sessionId': sessionId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isMocked': position.isMocked,
        'faceVerified': faceVerified,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AttendanceResult(
      success: data['success'] == true,
      message: data['message'] as String? ?? 'Unknown error.',
    );
  }
}

class AttendanceResult {
  final bool success;
  final String message;
  AttendanceResult({required this.success, required this.message});
}