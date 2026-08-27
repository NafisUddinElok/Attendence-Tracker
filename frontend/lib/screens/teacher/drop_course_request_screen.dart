import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class DropCourseRequestScreen extends StatefulWidget {
  final CourseModel course;
  const DropCourseRequestScreen({super.key, required this.course});

  @override
  State<DropCourseRequestScreen> createState() => _DropCourseRequestScreenState();
}

class _DropCourseRequestScreenState extends State<DropCourseRequestScreen> {
  final _regNoController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _statusMessage;
  bool _isError = false;

  Future<void> _sendRequest() async {
    if (_regNoController.text.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a registration number';
        _isError = true;
      });
      return;
    }

    setState(() {
      _sending = true;
      _statusMessage = null;
    });

    try {
      final res = await ApiService.post(ApiConfig.teacherDropCourseRequest, {
        'course_id': widget.course.id,
        'student_registration_number': _regNoController.text.trim(),
        'message': _messageController.text.trim(),
      });
      ApiService.decodeOrThrow(res);
      setState(() {
        _statusMessage = 'Request sent to admin for approval.';
        _isError = false;
        _regNoController.clear();
        _messageController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drop-Course Enrollment Request')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This sends a request to admin to enroll a student (who dropped '
              'another course) into "${widget.course.courseName}".',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _regNoController,
              decoration: const InputDecoration(
                labelText: 'Student Registration Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sending ? null : _sendRequest,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _sending
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Request to Admin'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _isError ? Colors.red : Colors.green.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
