import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../providers/auth_provider.dart';

final _historyProvider =
    FutureProvider.autoDispose<List<AttendanceHistory>>((ref) {
  return ref.read(apiClientProvider).getAttendanceHistory();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedCourseFilter;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_historyProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child:
                Text(e.toString(), style: const TextStyle(color: Colors.red)),
          ),
          data: (history) {
            if (history.isEmpty) {
              return const Center(
                child: Text('No attendance records yet.',
                    style: TextStyle(color: Colors.black54)),
              );
            }

            final courses = history.map((h) => h.subjectCode).toSet().toList()
              ..sort();

            final filteredHistory = _selectedCourseFilter == null
                ? history
                : history
                    .where((h) => h.subjectCode == _selectedCourseFilter)
                    .toList();

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Courses'),
                          selected: _selectedCourseFilter == null,
                          onSelected: (_) =>
                              setState(() => _selectedCourseFilter = null),
                        ),
                        const SizedBox(width: 6),
                        ...courses.map((c) {
                          final selected = _selectedCourseFilter == c;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: selected,
                              onSelected: (_) => setState(() =>
                                  _selectedCourseFilter = selected ? null : c),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, i) {
                      final h = filteredHistory[i];
                      final dt =
                          h.scannedAt != null ? _formatDate(h.scannedAt!) : '—';

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: Text(
                            h.subjectCode,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${h.subjectName ?? ''}\n$dt',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Text(
                            'PRESENT',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(String dt) {
    try {
      final d = DateTime.parse(dt).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(d);
    } catch (_) {
      return dt;
    }
  }
}
