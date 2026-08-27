import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/course_model.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import 'session_active_screen.dart';
import 'drop_course_request_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final CourseModel course;
  const CourseDetailScreen({super.key, required this.course});

  // Opens the CSV download link in the device browser.
  // Since the endpoint requires a JWT, we append it as a query param that
  // your backend can additionally accept (or open a WebView with headers
  // in a production app). Simplest approach: open in browser with token.
  Future<void> _downloadSummaryCsv(BuildContext context) async {
    final token = await AuthService.getToken();
    final url = '${ApiConfig.teacherCourseSummaryCsv(course.id)}?token=$token';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(course.courseName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_fill, color: Colors.green),
              title: const Text('Start Class Session'),
              subtitle: const Text('Opens attendance for students in range'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionActiveScreen(course: course),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Colors.indigo),
              title: const Text('Download Student-wise Summary CSV'),
              subtitle: const Text('Full attendance history for this course'),
              onTap: () => _downloadSummaryCsv(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: Colors.orange),
              title: const Text('Request Drop-Course Enrollment'),
              subtitle: const Text('Manually add a student by registration number'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DropCourseRequestScreen(course: course),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
