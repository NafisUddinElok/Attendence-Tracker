import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

// ===========================================================
// DI providers
// ===========================================================

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final c = ApiClient();
  // Late-bind the access-token provider after the controller exists.
  // We do this by reading the storage synchronously on every request.
  c.setAccessTokenProvider(() async {
    final s = await ref.read(secureStorageProvider).readAccessToken();
    return s;
  });
  return c;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
      ref.watch(authApiProvider), ref.watch(secureStorageProvider)),
);

// ===========================================================
// State
// ===========================================================

/// AsyncValue<AuthSession?>:
///  - data == null  => unauthenticated (after bootstrap)
///  - data != null  => authenticated
///  - loading/initial => bootstrap in flight
class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._repo) : super(const AsyncValue.loading());

  final AuthRepository _repo;

  Future<void> bootstrap() async {
    try {
      final s = await _repo.readPersistedSession();
      state = AsyncValue.data(s);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final s = await _repo.login(email, password);
      state = AsyncValue.data(s);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> registerStudent({
    required String fullName,
    required String email,
    required String password,
    required String registrationNo,
    String? department,
    String? session,
  }) async {
    state = const AsyncValue.loading();
    try {
      final s = await _repo.registerStudent(
        fullName: fullName,
        email: email,
        password: password,
        registrationNo: registrationNo,
        department: department,
        session: session,
      );
      state = AsyncValue.data(s);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    required String teacherId,
    String? department,
    String? designation,
  }) async {
    state = const AsyncValue.loading();
    try {
      final s = await _repo.registerTeacher(
        fullName: fullName,
        email: email,
        password: password,
        teacherId: teacherId,
        department: department,
        designation: designation,
      );
      state = AsyncValue.data(s);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      state = const AsyncValue.data(null);
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
