import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';
import '../../widgets/glass_card.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final classesAsync = ref.watch(teacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(teacherClassesProvider),
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
                'Assigned Classes',
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
                              ref.invalidate(teacherClassesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (classes) {
                    if (classes.isEmpty) {
                      return const Center(
                        child: Text('No classes assigned yet.',
                            style: TextStyle(color: Colors.black54)),
                      );
                    }
                    return ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, i) =>
                          _TeacherClassCard(classModel: classes[i]),
                    );
                  },
                ),
              ),
              BottomRightProfileWidget(
                title: user?.email ?? 'Faculty Member',
                subtitle: user?.department ?? 'Department',
                role: 'TEACHER',
                icon: Icons.school,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherClassCard extends StatelessWidget {
  final ClassModel classModel;

  const _TeacherClassCard({required this.classModel});

  @override
  Widget build(BuildContext context) {
    final c = classModel;
    final hasSession = c.hasActiveSession;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasSession ? Colors.blue : const Color(0xFFE0E0E0),
          width: hasSession ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                c.subjectCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              if (hasSession)
                const Text(
                  '● LIVE SESSION',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (c.subjectName != null) ...[
            const SizedBox(height: 2),
            Text(
              c.subjectName!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '${c.studentCount ?? 0} Students • Session ${c.academicSession}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSession ? Colors.green : Colors.blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => context.push('/teacher/session/${c.id}'),
                  child: Text(hasSession ? 'LIVE RADAR' : 'START'),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => context.push('/teacher/students/${c.id}'),
                child: const Text('Students'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => context.push('/teacher/report/${c.id}'),
                child: const Text('Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
