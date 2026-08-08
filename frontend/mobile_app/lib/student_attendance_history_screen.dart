// lib/student_attendance_history_screen.dart
//
// A student's own attendance record for one enrolled course, via
// GET /courses/:id/my-attendance. No CSV export here — that's a teacher-only
// action; a student only ever needs to see their own rows, not a file.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  final Course course;
  const StudentAttendanceHistoryScreen({super.key, required this.course});

  @override
  State<StudentAttendanceHistoryScreen> createState() => _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState extends State<StudentAttendanceHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<AttendanceRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await AttendanceService.getMyAttendance(widget.course.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _records = result.records;
      } else {
        _error = result.message;
      }
    });
  }

  String _formatMarkedAt(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.course.courseName} — My Attendance')),
      body: RefreshIndicator(
        onRefresh: _load,
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
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_records.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text("You haven't marked attendance for this course yet.")),
        ],
      );
    }
    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = _records[index];
        return ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(r.sessionLabel),
          subtitle: Text(_formatMarkedAt(r.markedAt)),
          trailing: Text(
            '${r.distanceMeters.round()}m',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }
}