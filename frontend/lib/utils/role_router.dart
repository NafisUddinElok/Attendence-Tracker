import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/student/student_home_screen.dart';

class RoleRouter {
  static void navigateToHome(BuildContext context, AppUser user) {
    Widget destination;

    switch (user.role) {
      case 'admin':
        destination = const AdminHomeScreen();
        break;
      case 'teacher':
        destination = TeacherHomeScreen(user: user);
        break;
      case 'student':
        destination = StudentHomeScreen(user: user);
        break;
      default:
        destination = const Scaffold(
          body: Center(child: Text('Unknown role')),
        );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
