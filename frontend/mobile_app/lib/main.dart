import 'package:flutter/material.dart';
import 'role_select_screen.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofence Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RoleSelectScreen(),
    );
  }
}