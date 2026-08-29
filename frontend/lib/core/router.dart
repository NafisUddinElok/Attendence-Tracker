import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/create_student_screen.dart';
import '../screens/admin/create_teacher_screen.dart';
import '../screens/admin/create_class_screen.dart';
import '../screens/admin/class_list_screen.dart';
import '../screens/admin/reset_password_screen.dart';
import '../screens/teacher/teacher_dashboard_screen.dart';
import '../screens/teacher/live_session_screen.dart';
import '../screens/teacher/students_screen.dart';
import '../screens/teacher/report_screen.dart';
import '../screens/student/student_dashboard_screen.dart';
import '../screens/student/class_screen.dart';
import '../screens/student/history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = authState.isLoggedIn;
      final onLogin = state.matchedLocation == '/';

      if (!loggedIn) return onLogin ? null : '/';
      if (onLogin) {
        final role = authState.role;
        return switch (role) {
          kRoleAdmin => '/admin',
          kRoleTeacher => '/teacher',
          kRoleStudent => '/student',
          _ => '/',
        };
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginScreen()),

      // ── Admin ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'create-student',
            builder: (_, __) => const CreateStudentScreen(),
          ),
          GoRoute(
            path: 'create-teacher',
            builder: (_, __) => const CreateTeacherScreen(),
          ),
          GoRoute(
            path: 'create-class',
            builder: (_, __) => const CreateClassScreen(),
          ),
          GoRoute(
            path: 'classes',
            builder: (_, __) => const ClassListScreen(),
          ),
          GoRoute(
            path: 'reset-password',
            builder: (_, __) => const ResetPasswordScreen(),
          ),
        ],
      ),

      // ── Teacher ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/teacher',
        builder: (_, __) => const TeacherDashboardScreen(),
        routes: [
          GoRoute(
            path: 'session/:classId',
            builder: (_, state) =>
                LiveSessionScreen(classId: state.pathParameters['classId']!),
          ),
          GoRoute(
            path: 'students/:classId',
            builder: (_, state) =>
                StudentsScreen(classId: state.pathParameters['classId']!),
          ),
          GoRoute(
            path: 'report/:classId',
            builder: (_, state) =>
                ReportScreen(classId: state.pathParameters['classId']!),
          ),
        ],
      ),

      // ── Student ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/student',
        builder: (_, __) => const StudentDashboardScreen(),
        routes: [
          GoRoute(
            path: 'class/:classId',
            builder: (_, state) =>
                ClassScreen(classId: state.pathParameters['classId']!),
          ),
          GoRoute(
            path: 'history',
            builder: (_, __) => const HistoryScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
