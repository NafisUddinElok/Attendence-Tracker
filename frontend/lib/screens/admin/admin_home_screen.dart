import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'manage_teachers_screen.dart';
import 'manage_students_screen.dart';
import 'manage_courses_screen.dart';
import 'notifications_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _TileData('Teachers', Icons.person, Colors.indigo, const ManageTeachersScreen()),
      _TileData('Students', Icons.school, Colors.teal, const ManageStudentsScreen()),
      _TileData('Courses', Icons.menu_book, Colors.orange, const ManageCoursesScreen()),
      _TileData('Notifications', Icons.notifications, Colors.red, const NotificationsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: tiles.map((tile) {
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => tile.screen),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tile.icon, size: 40, color: tile.color),
                  const SizedBox(height: 12),
                  Text(tile.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TileData {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
  _TileData(this.label, this.icon, this.color, this.screen);
}
