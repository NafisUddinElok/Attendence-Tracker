// lib/teacher_attendance_history_screen.dart
//
// Shows every attendance record for one of the teacher's courses, newest
// first, via GET /courses/:id/attendance (JSON). The "Download CSV" action
// hits the existing /courses/:id/attendance-export route and hands the file
// to the OS share sheet — see AttendanceService.downloadAttendanceCsv for
// why share instead of save-to-disk.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class TeacherAttendanceHistoryScreen extends StatefulWidget {
  final Course course;
  const TeacherAttendanceHistoryScreen({super.key, required this.course});

  @override
  State<TeacherAttendanceHistoryScreen> createState() => _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState extends State<TeacherAttendanceHistoryScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
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
    final result = await AttendanceService.getCourseAttendance(widget.course.id);
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

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    final result = await AttendanceService.downloadAttendanceCsv(
      widget.course.id,
      widget.course.courseCode,
    );
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
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
      appBar: AppBar(
        title: Text('${widget.course.courseName} — Attendance'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: _isExporting ? null : _exportCsv,
          ),
        ],
      ),
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
          const Center(child: Text('No attendance marked for this course yet.')),
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
          title: Text(r.studentName ?? 'Unknown student'),
          subtitle: Text('${r.studentCode ?? ''} · ${r.sessionLabel}'),
          trailing: Text(
            '${_formatMarkedAt(r.markedAt)}\n${r.distanceMeters.round()}m',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }
}