import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import '../../main.dart'; // Points to RoleSelectionHomeScreen or Dashboard

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Artificial 1.5s delay for smooth splash experience
    await Future.delayed(const Duration(milliseconds: 1500));

    final token = await _storage.read(key: 'jwt_token');
    final role = await _storage.read(key: 'user_role');

    if (!mounted) return;

    if (token != null && token.isNotEmpty && role != null) {
      // User is already logged in -> Navigate directly to Main Hub
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionHomeScreen()),
      );
    } else {
      // No valid session -> Go to Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 80,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SUST Attendance',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Anti-Proxy Biometric & Geofence System',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }
}