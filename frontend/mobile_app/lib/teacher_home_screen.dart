// lib/teacher_home_screen.dart
//
// Placeholder landing screen for teachers after login. Course creation and
// geofenced session-start UI will replace this body in the next step —
// kept minimal here so the role/login flow can be tested end-to-end first.

import 'package:flutter/material.dart';
import 'attendence_service.dart';
import 'role_select_screen.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AttendanceService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: AttendanceService.getName(),
        builder: (context, snapshot) {
          final name = snapshot.data;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.construction, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    name != null ? 'Welcome, $name' : 'Logged in as teacher',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Course creation and session start (geofencing) are coming next.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}