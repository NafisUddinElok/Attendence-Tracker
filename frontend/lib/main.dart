import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'screens/student/student_home_screen.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const SplashCheckScreen(),
    );
  }
}

/// Checks if a user is already logged in (token saved locally) and routes
/// directly to their role's home screen; otherwise shows the login screen.
class SplashCheckScreen extends StatefulWidget {
  const SplashCheckScreen({super.key});

  @override
  State<SplashCheckScreen> createState() => _SplashCheckScreenState();
}

class _SplashCheckScreenState extends State<SplashCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getToken();
    final user = await AuthService.getCurrentUser();

    await Future.delayed(const Duration(milliseconds: 400)); // brief splash

    if (!mounted) return;

    if (token == null || user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    Widget destination;
    switch (user.role) {
      case 'admin':
        destination = const AdminHomeScreen();
        break;
      case 'teacher':
        destination = TeacherHomeScreen(user: user);
        break;
      case 'student':
        destination = StudentHomeScreen(user: user);
        break;
      default:
        destination = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
