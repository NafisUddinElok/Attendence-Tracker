import 'package:flutter/material.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/courses/student_courses_screen.dart';
import 'screens/courses/teacher_courses_screen.dart';
import 'screens/face_register_screen.dart';
import 'screens/student_attendance_screen.dart';
import 'screens/student_history_screen.dart';
import 'screens/profile_screen.dart';
import 'services/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SUST Attendance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class RoleSelectionHomeScreen extends StatelessWidget {
  const RoleSelectionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('SUST Attendance Hub'),
        actions: [
          // Quick Server IP Config Dialog
          IconButton(
            icon: const Icon(Icons.dns_rounded),
            tooltip: 'Server IP Settings',
            onPressed: () => AppConfig.showServerConfigDialog(context),
          ),
          // Profile & Device Binding Screen
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Security',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 60, color: Colors.indigo),
            const SizedBox(height: 10),
            const Text(
              'Shahjalal University of Science & Technology',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const Text(
              'Anti-Proxy Attendance Hub',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 28),

            // TEACHER PORTAL
            _buildSectionHeader('INSTRUCTOR & FACULTY PORTAL'),
            const SizedBox(height: 10),
            _buildHubTile(
              context: context,
              icon: Icons.class_outlined,
              title: 'Manage Courses & Start Sessions',
              subtitle: 'Create courses, start dynamic QR sessions & view reports',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeacherCoursesScreen()),
              ),
            ),

            const SizedBox(height: 24),

            // STUDENT PORTAL
            _buildSectionHeader('STUDENT PORTAL'),
            const SizedBox(height: 10),
            _buildHubTile(
              context: context,
              icon: Icons.menu_book_rounded,
              title: 'Course Catalog & Enrollment',
              subtitle: 'Enroll in courses, view enrolled classes or drop',
              color: Colors.blue.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentCoursesScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _buildHubTile(
              context: context,
              icon: Icons.camera_alt_outlined,
              title: 'Mark 5-Step Attendance',
              subtitle: 'Face scan, eye blink liveness, and dynamic QR scanner',
              color: Colors.green.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentAttendanceScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _buildHubTile(
              context: context,
              icon: Icons.bar_chart_rounded,
              title: 'My Attendance & 75% Eligibility',
              subtitle: 'Collegiate, non-collegiate status & check-in timeline',
              color: Colors.teal.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentHistoryScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _buildHubTile(
              context: context,
              icon: Icons.fingerprint,
              title: 'Register Biometrics & Device',
              subtitle: 'Bind your phone UUID and 192-D face embedding',
              color: Colors.blueGrey.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FaceRegisterScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHubTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 24,
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}