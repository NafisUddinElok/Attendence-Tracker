// lib/student_join_course_screen.dart
//
// Primary enroll path: student types the courseCode the teacher gave them
// (written on the board, shared in a group chat, etc.) instead of browsing
// every course in the system. Hits POST /courses/join.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class StudentJoinCourseScreen extends StatefulWidget {
  const StudentJoinCourseScreen({super.key});

  @override
  State<StudentJoinCourseScreen> createState() => _StudentJoinCourseScreenState();
}

class _StudentJoinCourseScreenState extends State<StudentJoinCourseScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _error;

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the course code your teacher gave you.');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    final result = await AttendanceService.joinCourseByCode(code);

    if (!mounted) return;
    setState(() => _isJoining = false);

    if (result.success) {
      // Pop back to StudentCoursesScreen with `true` so it refreshes and
      // shows the newly-joined course.
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.courseName != null ? 'Joined ${result.courseName}' : result.message)),
      );
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Course')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 56, color: Colors.blue),
            const SizedBox(height: 12),
            const Text(
              'Ask your teacher for the course code and enter it below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Course Code',
                helperText: 'e.g. CS101',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _join(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            _isJoining
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _join,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Join'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}