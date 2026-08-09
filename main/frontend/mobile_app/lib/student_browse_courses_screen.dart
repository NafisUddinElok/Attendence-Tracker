// lib/student_browse_courses_screen.dart
//
// GET /courses/all (every course in the system) with an Enroll button per
// row that hits POST /courses/enroll. Pops back with `true` if at least one
// enroll succeeded so StudentCoursesScreen knows to refresh.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class StudentBrowseCoursesScreen extends StatefulWidget {
  const StudentBrowseCoursesScreen({super.key});

  @override
  State<StudentBrowseCoursesScreen> createState() => _StudentBrowseCoursesScreenState();
}

class _StudentBrowseCoursesScreenState extends State<StudentBrowseCoursesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Course> _courses = [];

  // Tracks courseIds currently mid-enroll-request, and ones already enrolled
  // this session, so the button can show a spinner then flip to a check.
  final Set<int> _enrolling = {};
  final Set<int> _enrolled = {};
  bool _didEnrollAny = false;

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
    final result = await AttendanceService.getAllCourses();
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

  Future<void> _enroll(Course course) async {
    setState(() => _enrolling.add(course.id));
    final result = await AttendanceService.enrollCourse(course.id);
    if (!mounted) return;
    setState(() => _enrolling.remove(course.id));

    if (result.success) {
      setState(() {
        _enrolled.add(course.id);
        _didEnrollAny = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intercept the system back gesture too (not just the AppBar button) so
    // StudentCoursesScreen finds out whether to refresh regardless of how
    // the user leaves this screen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _didEnrollAny);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Browse Courses')),
        body: RefreshIndicator(
          onRefresh: _loadCourses,
          child: _buildBody(),
        ),
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
          const Center(child: Text('No courses have been created yet.')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _courses.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final course = _courses[index];
        final isEnrolling = _enrolling.contains(course.id);
        final isEnrolled = _enrolled.contains(course.id);
        return ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(course.courseName),
          subtitle: Text(course.courseCode),
          trailing: isEnrolling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : isEnrolled
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: () => _enroll(course),
                      child: const Text('Enroll'),
                    ),
        );
      },
    );
  }
}