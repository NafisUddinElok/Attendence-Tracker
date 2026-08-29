import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(adminClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Classes'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminClassesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminClassesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return const Center(
                child: Text('No classes found.',
                    style: TextStyle(color: Colors.black54)),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminClassesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: classes.length,
                itemBuilder: (context, i) {
                  final c = classes[i];
                  final isActive = c.status == 'ACTIVE';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                c.subjectCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                c.status,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (c.subjectName != null &&
                              c.subjectName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              c.subjectName!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Dept: ${c.department} • Session: ${c.academicSession} • Students: ${c.studentCount ?? 0}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                          ),
                          if (c.teacherEmail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Teacher: ${c.teacherEmail}',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('End Class'),
                                      content: Text(
                                          'End "${c.subjectCode}"? It will be archived.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('END CLASS',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    await ref
                                        .read(apiClientProvider)
                                        .endClass(c.id);
                                    ref.invalidate(adminClassesProvider);
                                    ref.invalidate(teacherClassesProvider);
                                    ref.invalidate(studentClassesProvider);
                                  }
                                },
                                child: const Text('END CLASS'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
