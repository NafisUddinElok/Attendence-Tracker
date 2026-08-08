// lib/teacher_courses_screen.dart
//
// Teacher's main screen after login: lists their courses, lets them create
// a new one, and tapping a course goes to the session-start screen (set
// geofence + duration for that course).

import 'package:flutter/material.dart';
import 'attendence_service.dart';
import 'role_select_screen.dart';
import 'teacher_attendance_history_screen.dart';
import 'teacher_create_course_screen.dart';
import 'teacher_session_start_screen.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await AttendanceService.getMyCourses();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _courses = result.courses;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _createCourse() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TeacherCreateCourseScreen()),
    );
    if (created == true) _loadCourses();
  }

  Future<void> _logout() async {
    await AttendanceService.logout();
    if (!mounted) return;
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
        title: const Text('My Courses'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCourse,
        icon: const Icon(Icons.add),
        label: const Text('New course'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCourses,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _loadCourses, child: const Text('Retry'))),
        ],
      );
    }
    if (_courses.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('No courses yet. Tap "New course" to add one.')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _courses.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final course = _courses[index];
        return ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text(course.courseName),
          subtitle: Text(course.courseCode),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Attendance history',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeacherAttendanceHistoryScreen(course: course)),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeacherSessionStartScreen(course: course)),
          ),
        );
      },
    );
  }
}