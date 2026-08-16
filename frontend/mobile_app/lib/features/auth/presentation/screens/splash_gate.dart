import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_controller.dart';
import '../../domain/role.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';

/// Reads the persisted session from secure storage and dispatches:
///  - loading   -> spinner
///  - error     -> login
///  - data==null-> login
///  - data!=null-> role home
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).bootstrap();
      if (mounted) setState(() => _bootstrapped = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final state = ref.watch(authControllerProvider);
    final session = state.value;

    if (session == null) {
      return const LoginScreen();
    }
    return session.user.role == AppRole.student
        ? const StudentHomeScreen()
        : const TeacherHomeScreen();
  }
}

/// Convenience route so login_screen can push to register.
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/register':
      return MaterialPageRoute(builder: (_) => const RegisterScreen());
  }
  return null;
}
