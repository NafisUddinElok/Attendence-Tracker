/// Mirrors the backend error envelope:
///
/// ```json
/// { "error": { "code": "AUTH_INVALID_CREDENTIALS", "message": "...", "details": ... } }
/// ```
class ApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.code,
    required this.message,
    this.status,
    this.details,
  });

  factory ApiException.fromBody(int status, Map<String, dynamic> body) {
    final err = body['error'];
    if (err is Map) {
      return ApiException(
        code: (err['code'] ?? 'UNKNOWN').toString(),
        message: (err['message'] ?? 'Unknown error').toString(),
        status: status,
        details: err['details'] is Map
            ? Map<String, dynamic>.from(err['details'] as Map)
            : null,
      );
    }
    return ApiException(
      code: 'UNKNOWN',
      message: body.toString(),
      status: status,
    );
  }

  factory ApiException.network(String message) =>
      ApiException(code: 'NETWORK_ERROR', message: message);

  factory ApiException.timeout(String message) =>
      ApiException(code: 'TIMEOUT', message: message);

  @override
  String toString() => '[$code] $message';
}
