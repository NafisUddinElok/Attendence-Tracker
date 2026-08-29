import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/models/models.dart';
import '../data/repositories/api_client.dart';

// ── Auth State ───────────────────────────────────────────────────────────────

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;
  String get role => user?.role ?? '';

  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUserKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = AuthState(user: AuthUser.fromJson(json));
      } catch (_) {}
    }
  }

  Future<bool> login(String emailOrReg, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await ApiClient().login(emailOrReg, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kUserKey, jsonEncode(user.toJson()));
      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (e) {
      state = AuthState(error: 'Connection error. Is the server running?');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserKey);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Convenient provider for the API client with current token.
final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider).user?.token;
  return ApiClient(token: token);
});
