import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/user.dart';

/// Thin wrapper around the /api/v1/auth endpoints. All exceptions surface as
/// ApiException with the backend's {code, message, details} shape.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> registerStudent({
    required String fullName,
    required String email,
    required String password,
    required String registrationNo,
    String? department,
    String? session,
  }) async {
    final body = {
      'fullName': fullName,
      'email': email,
      'password': password,
      'registrationNo': registrationNo,
      if (department != null && department.isNotEmpty) 'department': department,
      if (session != null && session.isNotEmpty) 'session': session,
    };
    final res = await _client.post('/api/v1/auth/register/student', body);
    return _sessionFromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<AuthSession> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    required String teacherId,
    String? department,
    String? designation,
  }) async {
    final body = {
      'fullName': fullName,
      'email': email,
      'password': password,
      'teacherId': teacherId,
      if (department != null && department.isNotEmpty) 'department': department,
      if (designation != null && designation.isNotEmpty)
        'designation': designation,
    };
    final res = await _client.post('/api/v1/auth/register/teacher', body);
    return _sessionFromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return _sessionFromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<({String accessToken, String refreshToken})> refresh(
      String refreshToken) async {
    final res = await _client.post('/api/v1/auth/refresh', {
      'refreshToken': refreshToken,
    });
    final m = Map<String, dynamic>.from(res as Map);
    return (
      accessToken: m['accessToken'] as String,
      refreshToken: m['refreshToken'] as String,
    );
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/api/v1/auth/logout', {'refreshToken': refreshToken});
  }

  Future<User> me() async {
    final res = await _client.get('/api/v1/auth/me');
    final m = Map<String, dynamic>.from(res as Map);
    return User.fromJson(Map<String, dynamic>.from(m['user'] as Map));
  }

  AuthSession _sessionFromJson(Map<String, dynamic> j) {
    return AuthSession(
      accessToken: j['accessToken'] as String,
      refreshToken: j['refreshToken'] as String,
      user: User.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
    );
  }
}
