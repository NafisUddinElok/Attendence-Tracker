import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';
import '../../widgets/glass_card.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final classesAsync = ref.watch(studentClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Attendance History',
            onPressed: () => context.push('/student/history'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(studentClassesProvider),
          ),
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
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Enrolled Classes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: classesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $e',
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(studentClassesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (classes) {
                    if (classes.isEmpty) {
                      return const Center(
                        child: Text('No enrolled classes found.',
                            style: TextStyle(color: Colors.black54)),
                      );
                    }
                    return ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, i) {
                        final c = classes[i];
                        final hasSession = c.hasActiveSession;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: hasSession
                                  ? Colors.green
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              hasSession ? Icons.sensors : Icons.menu_book,
                              color: hasSession ? Colors.green : Colors.blue,
                              size: 24,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  c.subjectCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (hasSession) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    '[LIVE]',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${c.subjectName ?? ''}${c.teacherEmail != null ? '\n${c.teacherEmail}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    hasSession ? Colors.green : Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              onPressed: () =>
                                  context.push('/student/class/${c.id}'),
                              child: Text(hasSession ? 'CLAIM' : 'VIEW'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              BottomRightProfileWidget(
                title: user?.registrationNo ?? 'Student',
                subtitle:
                    '${user?.department ?? ''} • ${user?.academicSession ?? ''}',
                role: 'STUDENT',
                icon: Icons.person,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
