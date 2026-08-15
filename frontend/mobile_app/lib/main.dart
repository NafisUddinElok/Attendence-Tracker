import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/courses/student_courses_screen.dart';
import 'screens/courses/teacher_courses_screen.dart';
import 'screens/face_register_screen.dart';
import 'screens/student_attendance_screen.dart';
import 'screens/student_history_screen.dart';
import 'screens/teacher_report_screen.dart';
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
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}

class RoleSelectionHomeScreen extends StatelessWidget {
  const RoleSelectionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeroCard(
              gradient: AppGradients.primaryDeep,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              radius: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _Brand(),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.dns_rounded, color: Colors.white),
                            tooltip: 'Server IP Settings',
                            onPressed: () => AppConfig.showServerConfigDialog(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                            tooltip: 'My Profile & Security',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Shahjalal University of\nScience & Technology',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Anti-Proxy\nAttendance Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Face · Geofence · TOTP QR',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
            sliver: SliverList.list(
              children: [
                const SectionHeader('Instructor & Faculty Portal'),
                _PortalCard(
                  gradient: AppGradients.teacher,
                  icon: Icons.class_outlined,
                  title: 'Manage Courses & Sessions',
                  subtitle: 'Create courses, start live QR sessions, view reports',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TeacherCoursesScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('Student Portal'),
                _PortalCard(
                  gradient: AppGradients.primary,
                  icon: Icons.menu_book_rounded,
                  title: 'Course Catalog & Enrollment',
                  subtitle: 'Enroll in courses, view enrolled classes or drop',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentCoursesScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _PortalCard(
                  gradient: AppGradients.success,
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Mark 5-Step Attendance',
                  subtitle: 'Face scan, eye-blink liveness, dynamic QR scanner',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentAttendanceScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _PortalCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                  ),
                  icon: Icons.bar_chart_rounded,
                  title: 'My Attendance & 75% Eligibility',
                  subtitle: 'Collegiate, non-collegiate status & check-in timeline',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentHistoryScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _PortalCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF64748B), Color(0xFF334155)],
                  ),
                  icon: Icons.fingerprint,
                  title: 'Register Biometrics & Device',
                  subtitle: 'Bind your phone UUID and 192-D face embedding',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FaceRegisterScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _SecurityNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'SUST Hub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PortalCard extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PortalCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      background: AppColors.primaryLight,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              '5-step verification keeps every check-in accountable: TOTP token, GPS fence, mock-location guard, hardware binding, and face similarity.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}