import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Typed wrapper around flutter_secure_storage.
/// All keys are namespaced with `auth.` so unrelated features can add their own.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? backend})
      : _s = backend ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  /// Process-wide singleton for screen-level convenience. Tests / DI may
  /// still build their own instance and pass it around.
  static final SecureStorage instance = SecureStorage();

  final FlutterSecureStorage _s;

  static const _kAccess = 'auth.accessToken';
  static const _kRefresh = 'auth.refreshToken';
  static const _kRole = 'auth.role';
  static const _kId = 'auth.id';
  static const _kName = 'auth.fullName';
  static const _kEmail = 'auth.email';

  Future<String?> readAccessToken() => _s.read(key: _kAccess);
  Future<String?> readRefreshToken() => _s.read(key: _kRefresh);
  Future<String?> readRole() => _s.read(key: _kRole);
  Future<String?> readId() => _s.read(key: _kId);
  Future<String?> readName() => _s.read(key: _kName);
  Future<String?> readEmail() => _s.read(key: _kEmail);

  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String id,
    required String fullName,
    required String email,
  }) async {
    await _s.write(key: _kAccess, value: accessToken);
    await _s.write(key: _kRefresh, value: refreshToken);
    await _s.write(key: _kRole, value: role);
    await _s.write(key: _kId, value: id);
    await _s.write(key: _kName, value: fullName);
    await _s.write(key: _kEmail, value: email);
  }

  Future<void> writeAccessToken(String token) =>
      _s.write(key: _kAccess, value: token);
  Future<void> writeRefreshToken(String token) =>
      _s.write(key: _kRefresh, value: token);

  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kRole);
    await _s.delete(key: _kId);
    await _s.delete(key: _kName);
    await _s.delete(key: _kEmail);
  }
}
