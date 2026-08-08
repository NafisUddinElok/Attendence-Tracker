// lib/student_courses_screen.dart
//
// Student's main screen after login: lists courses they're enrolled in.
// Tapping a course calls GET /sessions/active?courseId=... to resolve the
// current sessionId (if any class is live right now for that course), then
// pushes AttendanceScreen with that resolved id. If nothing is active,
// shows a dialog instead of navigating — there's nothing to mark attendance
// against.
//
// "Browse courses" (FAB) goes to StudentBrowseCoursesScreen to enroll in
// new courses; coming back with `true` refreshes this list.

import 'package:flutter/material.dart';
import 'attendence_service.dart';
import 'attendance_screen.dart';
import 'role_select_screen.dart';
import 'student_attendance_history_screen.dart';
import 'student_browse_courses_screen.dart';
import 'student_join_course_screen.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Course> _courses = [];

  // Tracks which course row is currently resolving its active session, so
  // only that ListTile shows a spinner instead of blocking the whole screen.
  int? _resolvingCourseId;

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
    final result = await AttendanceService.getEnrolledCourses();
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

  Future<void> _openCourse(Course course) async {
    setState(() => _resolvingCourseId = course.id);
    final session = await AttendanceService.getActiveSession(course.id);
    if (!mounted) return;
    setState(() => _resolvingCourseId = null);

    if (!session.success || session.sessionId == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No active session'),
          content: Text(
            session.message.isNotEmpty
                ? session.message
                : 'There is no active class session for ${course.courseName} right now.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          sessionId: session.sessionId!,
          courseName: course.courseName,
          sessionLabel: session.label,
        ),
      ),
    );
  }

  Future<void> _joinByCode() async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StudentJoinCourseScreen()),
    );
    if (joined == true) _loadCourses();
  }

  Future<void> _browseCourses() async {
    final enrolled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StudentBrowseCoursesScreen()),
    );
    if (enrolled == true) _loadCourses();
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
          TextButton.icon(
            onPressed: _browseCourses,
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text('Browse', style: TextStyle(color: Colors.white)),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinByCode,
        icon: const Icon(Icons.add),
        label: const Text('Join with code'),
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
          const Center(child: Text('Not enrolled in any courses yet.')),
          const SizedBox(height: 4),
          const Center(child: Text('Tap "Browse courses" to enroll.')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _courses.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final course = _courses[index];
        final isResolving = _resolvingCourseId == course.id;
        return ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text(course.courseName),
          subtitle: Text(course.courseCode),
          trailing: isResolving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: 'My attendance',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentAttendanceHistoryScreen(course: course),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
          onTap: isResolving ? null : () => _openCourse(course),
        );
      },
    );
  }
}