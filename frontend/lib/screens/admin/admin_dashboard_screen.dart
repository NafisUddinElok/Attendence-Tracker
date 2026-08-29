import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    final actions = [
      _ActionItem(
        icon: Icons.person_add,
        label: 'Add Student',
        subtitle: 'Auto-enroll by Reg No',
        route: '/admin/create-student',
      ),
      _ActionItem(
        icon: Icons.school,
        label: 'Add Teacher',
        subtitle: 'Add faculty member',
        route: '/admin/create-teacher',
      ),
      _ActionItem(
        icon: Icons.add_box,
        label: 'Create Classroom',
        subtitle: 'New course & auto-enroll',
        route: '/admin/create-class',
      ),
      _ActionItem(
        icon: Icons.list,
        label: 'Manage Classes',
        subtitle: 'View, monitor & end classes',
        route: '/admin/classes',
      ),
      _ActionItem(
        icon: Icons.lock_reset,
        label: 'Reset Password',
        subtitle: 'Override user password',
        route: '/admin/reset-password',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'LOGOUT',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: actions.length,
                  itemBuilder: (context, i) {
                    final item = actions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: ListTile(
                        leading: Icon(item.icon, color: Colors.blue, size: 24),
                        title: Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => context.push(item.route),
                      ),
                    );
                  },
                ),
              ),
              BottomRightProfileWidget(
                title: 'Admin',
                subtitle: user?.email ?? 'admin@example.com',
                role: 'ADMIN',
                icon: Icons.admin_panel_settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
  });
}
