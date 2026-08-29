import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/auth_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String classId;
  const ReportScreen({super.key, required this.classId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  AttendanceMatrix? _matrix;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matrix =
          await ref.read(apiClientProvider).getAttendanceMatrix(widget.classId);
      if (mounted) setState(() => _matrix = matrix);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final csv =
          await ref.read(apiClientProvider).getAttendanceCsv(widget.classId);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV copied to clipboard!'),
              backgroundColor: AppColors.presentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.absentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Matrix Report'),
        leading: const BackButton(),
        actions: [
          if (_matrix != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, color: Colors.white, size: 16),
              label: const Text('CSV',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _exportCsv,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.absentRed)))
                : _matrix == null
                    ? const SizedBox()
                    : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final m = _matrix!;

    return Column(
      children: [
        // Top summary metrics
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _MetricBox(label: 'Total Sessions', value: '${m.totalSessions}'),
              const SizedBox(width: 8),
              _MetricBox(label: 'Total Students', value: '${m.totalStudents}'),
              const SizedBox(width: 8),
              _MetricBox(
                  label: 'Avg Attendance',
                  value: '${m.averageAttendancePct.round()}%'),
            ],
          ),
        ),
        if (m.totalSessions == 0)
          const Expanded(
            child: Center(
                child: Text('No attendance sessions taken yet.',
                    style: TextStyle(color: AppColors.textSecondary))),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(AppColors.softBlue),
                    headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.schoolNavy,
                        fontSize: 12),
                    dataTextStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary),
                    columnSpacing: 16,
                    columns: [
                      const DataColumn(label: Text('Reg No')),
                      ...m.sessions.map((s) => DataColumn(
                            label: Text(_formatDate(s['startedAt'] as String?)),
                          )),
                      const DataColumn(label: Text('Total')),
                      const DataColumn(label: Text('%')),
                    ],
                    rows: [
                      ...m.rows.map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(r.registrationNo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                            ...r.cells.map(
                              (c) => DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c == 'P'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: c == 'P'
                                          ? AppColors.presentGreen
                                          : AppColors.absentRed,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                                Text('${r.totalPresent}/${r.totalSessions}')),
                            DataCell(
                              Text(
                                '${r.percentage.round()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: r.percentage < 75
                                      ? AppColors.absentRed
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(String? dt) {
    if (dt == null) return '—';
    try {
      final d = DateTime.parse(dt).toLocal();
      return '${d.month}/${d.day}';
    } catch (_) {
      return dt.substring(0, 5);
    }
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.schoolBlue)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
