// lib/teacher_bulk_import_screen.dart
//
// Lets a teacher paste a roster (studentCode,name per line — NO passwords)
// and bulk-create accounts for a new semester. Passwords are generated on
// the server and shown here exactly once. This screen deliberately does not
// persist the results anywhere (no local file, no shared_preferences) — the
// teacher must copy/relay them immediately. Closing this screen loses them,
// by design, so nothing sensitive lingers on the device.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'attendence_service.dart';

class TeacherBulkImportScreen extends StatefulWidget {
  const TeacherBulkImportScreen({super.key});

  @override
  State<TeacherBulkImportScreen> createState() => _TeacherBulkImportScreenState();
}

class _TeacherBulkImportScreenState extends State<TeacherBulkImportScreen> {
  final _rosterController = TextEditingController();
  bool _isLoadingCourses = true;
  bool _isImporting = false;
  List<Course> _courses = [];
  int? _selectedCourseId;
  List<BulkImportEntry>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final result = await AttendanceService.getMyCourses();
    if (!mounted) return;
    setState(() {
      _isLoadingCourses = false;
      if (result.success) _courses = result.courses;
    });
  }

  List<Map<String, String>> _parseRoster() {
    final lines = _rosterController.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    final students = <Map<String, String>>[];
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length < 2) continue;
      final code = parts[0].trim();
      final name = parts.sublist(1).join(',').trim();
      if (code.isEmpty || name.isEmpty) continue;
      students.add({'studentCode': code, 'name': name});
    }
    return students;
  }

  Future<void> _import() async {
    final students = _parseRoster();
    if (students.isEmpty) {
      setState(() => _error = 'Enter at least one line as: studentCode,name');
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
      _results = null;
    });

    final result = await AttendanceService.bulkImportStudents(students, courseId: _selectedCourseId);

    if (!mounted) return;
    setState(() {
      _isImporting = false;
      if (result.success) {
        _results = result.entries;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _copyAllToClipboard() async {
    final entries = _results;
    if (entries == null) return;
    final lines = entries
        .where((e) => e.status == 'created' && e.password != null)
        .map((e) => '${e.studentCode},${e.name},${e.password}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied. Paste this somewhere secure and delete it after sharing.')),
    );
  }

  @override
  void dispose() {
    _rosterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import Students')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Passwords are generated automatically and shown once below. '
                      'Never save them to a spreadsheet or commit them anywhere — '
                      'relay each one to its student directly, then discard.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Roster (one per line: studentCode,name)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _rosterController,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'STU010,Rahim Uddin\nSTU011,Karim Ahmed\nSTU012,Fatima Khan',
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingCourses)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text('Auto-enroll in course (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _selectedCourseId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Don\'t auto-enroll')),
                  ..._courses.map(
                    (c) => DropdownMenuItem<int?>(value: c.id, child: Text('${c.courseCode} — ${c.courseName}')),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedCourseId = value),
              ),
            ],
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            _isImporting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.group_add),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Import'),
                    ),
                  ),
            if (_results != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Results (${_results!.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _copyAllToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._results!.map(_buildResultTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(BulkImportEntry entry) {
    IconData icon;
    Color color;
    String subtitle;

    switch (entry.status) {
      case 'created':
        icon = Icons.check_circle;
        color = Colors.green;
        subtitle = 'Password: ${entry.password}';
        break;
      case 'already_existed':
        icon = Icons.info;
        color = Colors.blueGrey;
        subtitle = 'Already existed — password unchanged';
        break;
      default:
        icon = Icons.error;
        color = Colors.red;
        subtitle = entry.message ?? 'Error';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('${entry.studentCode} — ${entry.name}'),
        subtitle: Text(subtitle, style: entry.status == 'created' ? const TextStyle(fontFamily: 'monospace') : null),
        trailing: entry.status == 'created'
            ? IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy password',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.password ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied password for ${entry.studentCode}')),
                  );
                },
              )
            : null,
      ),
    );
  }
}