import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';
import 'endpoints.dart';

/// Bearer-token injection + uniform error handling.
/// Refresh is intentionally NOT done here — it lives in the auth feature
/// so the only consumer of refresh tokens owns the rotation policy.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    Future<String?> Function()? accessTokenProvider,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? Endpoints.baseUrl,
        _accessTokenProvider = accessTokenProvider;

  final http.Client _http;
  final String _baseUrl;
  Future<String?> Function()? _accessTokenProvider;

  void setAccessTokenProvider(Future<String?> Function() provider) {
    _accessTokenProvider = provider;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, String>> _headers({bool withJson = true}) async {
    final h = <String, String>{};
    if (withJson) h['Content-Type'] = 'application/json';
    final token = await (_accessTokenProvider?.call() ?? Future.value(null));
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<dynamic> get(String path) async {
    try {
      final r = await _http
          .get(_uri(path), headers: await _headers(withJson: false))
          .timeout(const Duration(seconds: 20));
      return _decode(r);
    } on TimeoutException {
      throw ApiException.timeout('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e.toString());
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final r = await _http
          .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return _decode(r);
    } on TimeoutException {
      throw ApiException.timeout('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e.toString());
    }
  }

  Future<dynamic> postNoBody(String path) async {
    try {
      final r = await _http
          .post(_uri(path), headers: await _headers(withJson: false))
          .timeout(const Duration(seconds: 20));
      return _decode(r);
    } on TimeoutException {
      throw ApiException.timeout('Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e.toString());
    }
  }

  dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? <String, dynamic>{} : _safeJson(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      // 204 No Content has no body — return null.
      if (r.statusCode == 204) return null;
      return body;
    }
    if (body is Map) {
      throw ApiException.fromBody(
          r.statusCode, Map<String, dynamic>.from(body));
    }
    throw ApiException(
      code: 'HTTP_${r.statusCode}',
      message: 'Request failed with ${r.statusCode}',
      status: r.statusCode,
    );
  }

  Object? _safeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
}
