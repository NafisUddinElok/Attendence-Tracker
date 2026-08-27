import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String url) async {
    return http.get(Uri.parse(url), headers: await _headers());
  }

  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    return http.post(Uri.parse(url), headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    return http.put(Uri.parse(url), headers: await _headers(), body: jsonEncode(body));
  }

  // Helper to decode + throw a readable error if request failed
  static dynamic decodeOrThrow(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw Exception(data['message'] ?? 'Request failed (${response.statusCode})');
  }
}
