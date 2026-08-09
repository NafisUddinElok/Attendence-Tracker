// lib/attendance_screen.dart
//
// Goes through AttendanceService so it hits /geofencing/mark-attendance with
// the stored JWT and a sessionId, rather than a raw studentId.
//
// sessionId now comes in from StudentCoursesScreen, which resolves it via
// GET /sessions/active?courseId=... right before navigating here — this
// screen no longer knows or cares about courseId, only the resolved session.

import 'package:flutter/material.dart';
import 'attendence_service.dart';
import 'face_liveness_screen.dart';
import 'role_select_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final int sessionId;
  final String courseName;
  final String? sessionLabel;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.courseName,
    this.sessionLabel,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;

  Future<void> _logout() async {
    await AttendanceService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  Future<void> _markAttendance() async {
    // 1. Run the on-device liveness check first. This opens the camera and
    // requires a blink before returning true.
    final faceVerified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );

    if (faceVerified != true) {
      // User cancelled or the check timed out/failed — don't even attempt
      // the network call.
      return;
    }

    setState(() => _isLoading = true);
    final result = await AttendanceService.markAttendance(widget.sessionId, faceVerified: true);
    setState(() => _isLoading = false);

    if (!mounted) return;
    _showDialog(result.success ? 'Success' : 'Failed', result.message);
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.sessionLabel != null) ...[
                    Text(widget.sessionLabel!, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: _markAttendance,
                    child: const Text('Mark Attendance'),
                  ),
                ],
              ),
      ),
    );
  }
}