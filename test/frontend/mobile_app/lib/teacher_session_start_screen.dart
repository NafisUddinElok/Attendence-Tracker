// lib/teacher_session_start_screen.dart
//
// Teacher stands in the classroom and taps "Start session". Their current
// GPS position (captured inside AttendanceService.startSession) becomes the
// geofence center — there's no manual lat/lng entry, which avoids a teacher
// accidentally typing the wrong coordinates.

import 'package:flutter/material.dart';
import 'attendence_service.dart';

class TeacherSessionStartScreen extends StatefulWidget {
  final Course course;
  const TeacherSessionStartScreen({super.key, required this.course});

  @override
  State<TeacherSessionStartScreen> createState() => _TeacherSessionStartScreenState();
}

class _TeacherSessionStartScreenState extends State<TeacherSessionStartScreen> {
  double _radiusMeters = 50;
  int _durationMinutes = 60;
  bool _isStarting = false;

  Future<void> _startSession() async {
    setState(() => _isStarting = true);
    final result = await AttendanceService.startSession(
      courseId: widget.course.id,
      radiusMeters: _radiusMeters.round(),
      durationMinutes: _durationMinutes,
    );
    setState(() => _isStarting = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Session started' : 'Could not start session'),
        content: Text(
          result.success
              ? 'Students within ${_radiusMeters.round()}m can now mark attendance for '
                  '${widget.course.courseName}. Active until ${_formatEndsAt(result.endsAt)}.'
              : result.message,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (result.success) Navigator.pop(context); // back to course list
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatEndsAt(String? iso) {
    if (iso == null) return 'unknown';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.courseName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on, size: 56, color: Colors.blue),
            const SizedBox(height: 8),
            const Text(
              'Starting a session uses your current location as the classroom '
              'center. Make sure you\'re standing where you want students to check in from.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Text('Geofence radius: ${_radiusMeters.round()} m',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              value: _radiusMeters,
              min: 10,
              max: 200,
              divisions: 19,
              label: '${_radiusMeters.round()} m',
              onChanged: (v) => setState(() => _radiusMeters = v),
            ),
            const SizedBox(height: 16),
            Text('Session length: $_durationMinutes minutes',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              value: _durationMinutes.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              label: '$_durationMinutes min',
              onChanged: (v) => setState(() => _durationMinutes = v.round()),
            ),
            const SizedBox(height: 32),
            _isStarting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _startSession,
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Start session', style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}