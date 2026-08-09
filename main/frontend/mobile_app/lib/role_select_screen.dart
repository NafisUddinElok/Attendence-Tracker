// lib/role_select_screen.dart
//
// First screen the app shows. Just decides which login flow to send the
// user into — no auth logic here. Kept deliberately dumb: the backend is
// the source of truth for role (from student-code vs teacher-code lookups
// against separate tables), this screen only picks which endpoint to call.

import 'package:flutter/material.dart';
import 'student_login_screen.dart';
import 'teacher_login_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 72, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Continue as',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Student', style: TextStyle(fontSize: 16)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.badge_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Teacher', style: TextStyle(fontSize: 16)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}