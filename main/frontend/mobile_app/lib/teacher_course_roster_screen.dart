// lib/teacher_course_roster_screen.dart
//
// Shows every student enrolled in one of the teacher's courses, via
// GET /courses/:id/students. Search filters the already-fetched list
// client-side (instant, no network round-trip per keystroke — see
// AttendanceService.getCourseRoster). The trash icon unenrolls a student
// from THIS course only; it does not delete their account or touch their
// attendance history anywhere.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class TeacherCourseRosterScreen extends StatefulWidget {
  final Course course;
  const TeacherCourseRosterScreen({super.key, required this.course});

  @override
  State<TeacherCourseRosterScreen> createState() => _TeacherCourseRosterScreenState();
}

class _TeacherCourseRosterScreenState extends State<TeacherCourseRosterScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  List<EnrolledStudent> _allStudents = [];
  List<EnrolledStudent> _filtered = [];

  // Tracks which studentId is mid-delete-request, so only that row shows a
  // spinner instead of blocking the whole screen.
  int? _removingStudentId;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await AttendanceService.getCourseRoster(widget.course.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _allStudents = result.students;
        _applyFilter();
      } else {
        _error = result.message;
      }
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allStudents
          : _allStudents
              .where((s) =>
                  s.name.toLowerCase().contains(query) || s.studentCode.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _confirmAndRemove(EnrolledStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from course?'),
        content: Text(
          '${student.name} (${student.studentCode}) will be unenrolled from '
          '${widget.course.courseName}. Their account and attendance history '
          'elsewhere are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removingStudentId = student.id);
    final result = await AttendanceService.removeStudentFromCourse(widget.course.id, student.id);
    if (!mounted) return;
    setState(() => _removingStudentId = null);

    if (result.success) {
      setState(() {
        _allStudents.removeWhere((s) => s.id == student.id);
        _applyFilter();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    final result = await AttendanceService.downloadRosterCsv(widget.course.id, widget.course.courseCode);
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.course.courseName} — Roster'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download roster CSV',
            onPressed: _isExporting ? null : _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or student code',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
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
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_allStudents.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('No students enrolled in this course yet.')),
        ],
      );
    }
    if (_filtered.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('No student matches that search.')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final student = _filtered[index];
        final isRemoving = _removingStudentId == student.id;
        return ListTile(
          leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?')),
          title: Text(student.name),
          subtitle: Text(student.studentCode),
          trailing: isRemoving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                  tooltip: 'Remove from course',
                  onPressed: () => _confirmAndRemove(student),
                ),
        );
      },
    );
  }
}