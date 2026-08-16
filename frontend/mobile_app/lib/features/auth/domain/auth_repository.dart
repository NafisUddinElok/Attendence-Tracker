import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import 'auth_session.dart';
import 'role.dart';
import 'user.dart';

/// Single source of truth for "the logged-in user".
/// Owns persistence (secure storage) and the API (AuthApi).
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final AuthApi _api;
  final SecureStorage _storage;

  Future<AuthSession?> readPersistedSession() async {
    final access = await _storage.readAccessToken();
    final refresh = await _storage.readRefreshToken();
    final id = await _storage.readId();
    final roleRaw = await _storage.readRole();
    final name = await _storage.readName();
    final email = await _storage.readEmail();
    if (access == null || refresh == null || id == null || roleRaw == null) {
      return null;
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: User(
        id: id,
        fullName: name ?? '',
        email: email ?? '',
        role: AppRole.fromWire(roleRaw),
      ),
    );
  }

  Future<AuthSession> login(String email, String password) async {
    final session = await _api.login(email: email, password: password);
    await _persist(session);
    return session;
  }

  Future<AuthSession> registerStudent({
    required String fullName,
    required String email,
    required String password,
    required String registrationNo,
    String? department,
    String? session,
  }) async {
    final s = await _api.registerStudent(
      fullName: fullName,
      email: email,
      password: password,
      registrationNo: registrationNo,
      department: department,
      session: session,
    );
    await _persist(s);
    return s;
  }

  Future<AuthSession> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    required String teacherId,
    String? department,
    String? designation,
  }) async {
    final s = await _api.registerTeacher(
      fullName: fullName,
      email: email,
      password: password,
      teacherId: teacherId,
      department: department,
      designation: designation,
    );
    await _persist(s);
    return s;
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // Best-effort.
      }
    }
    await _storage.clear();
  }

  Future<void> _persist(AuthSession s) async {
    await _storage.writeSession(
      accessToken: s.accessToken,
      refreshToken: s.refreshToken,
      role: s.user.role.wireValue,
      id: s.user.id,
      fullName: s.user.fullName,
      email: s.user.email,
    );
  }
}
