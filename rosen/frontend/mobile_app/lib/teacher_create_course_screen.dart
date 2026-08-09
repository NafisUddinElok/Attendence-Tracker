// lib/teacher_create_course_screen.dart

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class TeacherCreateCourseScreen extends StatefulWidget {
  const TeacherCreateCourseScreen({super.key});

  @override
  State<TeacherCreateCourseScreen> createState() => _TeacherCreateCourseScreenState();
}

class _TeacherCreateCourseScreenState extends State<TeacherCreateCourseScreen> {
  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _create() async {
    setState(() => _isLoading = true);
    final result = await AttendanceService.createCourse(
      _courseCodeController.text.trim(),
      _courseNameController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      // Pop back to the course list and tell it to refresh.
      Navigator.pop(context, true);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Could not create course'),
          content: Text(result.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _courseNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Course')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _courseCodeController,
              decoration: const InputDecoration(
                labelText: 'Course Code',
                helperText: 'e.g. CS101 — students will use this exact code to join, so pick something short and memorable',
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courseNameController,
              decoration: const InputDecoration(
                labelText: 'Course Name',
                helperText: 'e.g. Intro to Computer Science',
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _create,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Create'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}